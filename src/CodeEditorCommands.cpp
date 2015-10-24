#include <QApplication>
#include <QDir>
#include <QDebug>

#include "CodeEditor.h"
#include "Util.h"



////////////////////////////////////////////////////////////////////////////////
// being typedefs

typedef bool (*TiledEditorCommandHandler)(TiledEditor * editor, const QStringList & args_list);

// end typedefs
////////////////////////////////////////////////////////////////////////////////


// --------------------------------------------------------------------------------
// commandline handlers
// --------------------------------------------------------------------------------

bool newFile(TiledEditor * editor, const QStringList & args_list)
{
  qDebug() << "called newFile(" << args_list.join(", ") << ')';

  if (args_list.isEmpty()) {
    editor->newFile(NULL);
  } else {
    editor->newFile(&args_list.at(0));
  }

  return true;
}


bool open(TiledEditor * editor, const QStringList & args_list)
{
  qDebug() << "called open(" << args_list.join(", ") << ')';

  if (args_list.isEmpty()) {
    editor->printToConsole(TiledEditor::tr("please specify file"));
    return false;
  }

  bool success = editor->openFile(args_list.at(0));
  if (!success) {
    editor->printToConsole(TiledEditor::tr("failed to open \"%1\"").arg(args_list.at(0)));
  }

  return success;
}


bool save(TiledEditor * editor, const QStringList & args_list)
{
  qDebug() << "called save(" << args_list.join(", ") << ')';

  bool success = false;

  if (args_list.isEmpty()) {
    editor->printToConsole(TiledEditor::tr("please specify document"));
  } else if (args_list.size() == 1) {
    success = editor->saveFile(args_list.at(0));
    if (!success) {
      editor->printToConsole(TiledEditor::tr("failed to save \"%1\"").arg(args_list.at(0)));
    }
  } else {
    success = editor->saveFile(args_list.at(0), &args_list.at(1));
    if (!success) {
      editor->printToConsole(TiledEditor::tr("failed to save \"%1\" as \"%2\"").arg(args_list.at(0), args_list.at(1)));
    }
  }

  return success;
}


bool setActiveSubWindow(TiledEditor * editor, const QStringList & args_list)
{
  qDebug() << "called setActiveSubWindow(" << args_list.join(", ") << ')';

  if (args_list.isEmpty()) {
    editor->printToConsole(TiledEditor::tr("please specify document"));
    return false;
  }

  bool success = editor->setActiveSubWindow(args_list.at(0));
  if (!success) {
    editor->printToConsole(TiledEditor::tr("failed to activate \"%1\"").arg(args_list.at(0)));
  }

  return true;
}


bool tileSubWindows(TiledEditor * editor, const QStringList & args_list)
{
  qDebug() << "called tileSubWindows(" << args_list.join(", ") << ')';

  if (args_list.isEmpty()) {
    editor->tileSubWindowsHorizontally();
  } else if (args_list.at(0).startsWith('h', Qt::CaseInsensitive)) {
    editor->tileSubWindowsHorizontally();
  } else if (args_list.at(0).startsWith('v', Qt::CaseInsensitive)) {
    editor->tileSubWindowsVertically();
  } else {
    editor->printToConsole(TiledEditor::tr("invalid parameter \"%1\"").arg(args_list.at(0)));
    return false;
  }

  return true;
}


bool setSessionLog(TiledEditor * editor, const QStringList & args_list)
{
  if (args_list.isEmpty()) {
    editor->printToConsole(TiledEditor::tr("please specify on or off"));
    return false;
  }

  bool success = false;
  QString param = args_list.at(0).toLower();
  if (param == "on") {
    QString log_filename = (args_list.size() >= 2) ? args_list.at(1) : "session.out";
    success = editor->startSessionLog(log_filename);
  } else if (param == "off") {
    success = editor->stopSessionLog();
  } else {
    editor->printToConsole(TiledEditor::tr("invalid parameter \"%1\"").arg(args_list.at(0)));
  }
  return success;
}


bool runCommandScript(TiledEditor * editor, const QStringList & args_list)
{
  static QSet<QString> active_scripts;

  if (args_list.isEmpty()) {
    return false;
  }

  const QString & script_path = args_list.at(0);
  if (active_scripts.contains(script_path)) {
    editor->printToConsole(TiledEditor::tr("script \"%1\" is already running, cannot recurse").arg(script_path));
    return false;
  }

  bool success = false;
  active_scripts.insert(script_path);

  QFile script_file(script_path);
  if (script_file.open(QIODevice::ReadOnly)) {
    QTextStream in_stream(&script_file);
    while (!in_stream.atEnd()) {
      QString line = in_stream.readLine();
      success = editor->handleCommand(line);
      if(!success) {
        break;
      }
    }
    script_file.close();
  }

  active_scripts.remove(script_path);
  return success;
}


bool printWorkingDirectory(TiledEditor * editor, const QStringList &)
{
  editor->printToConsole(QDir::currentPath());
  return true;
}


bool listWorkingDirectory(TiledEditor * editor, const QStringList & args_list)
{
  QDir cwd = QDir::current();
  QStringList entries = args_list.isEmpty() ? cwd.entryList() : cwd.entryList(args_list);
  for (int i = 0; i < entries.size(); ++i) {
    editor->printToConsole(entries.at(i));
  }
  return true;
}


bool changeWorkingDirectory(TiledEditor * editor, const QStringList & args_list)
{
  if (args_list.isEmpty()) {
    return false;
  }

  bool success = QDir::setCurrent(args_list.at(0));

  if (success) {
    editor->printToConsole(TiledEditor::tr("changed directory to \"%1\"").arg(QDir::currentPath()));
  } else {
    editor->printToConsole(TiledEditor::tr("failed to change directory"));
  }

  return success;
}


bool exitApplication(TiledEditor * editor, const QStringList &)
{
  editor->printToConsole(TiledEditor::tr("exiting..."));
  qApp->closeAllWindows();
  return true;
}



// --------------------------------------------------------------------------------
// list of commandline handlers
// --------------------------------------------------------------------------------

const QHash<QString, TiledEditorCommandHandler> generateCommandHandlers()
{
  QHash<QString, TiledEditorCommandHandler> cmd_map;

  cmd_map["cwd"] = printWorkingDirectory;
  cmd_map["pwd"] = printWorkingDirectory;
  cmd_map["ls"] = listWorkingDirectory;
  cmd_map["cd"] = changeWorkingDirectory;

  cmd_map["record"] = setSessionLog;
  cmd_map["play"] = runCommandScript;

  cmd_map["new"] = newFile;
  cmd_map["open"] = open;
  cmd_map["save"] = save;
  cmd_map["activate"] = setActiveSubWindow;
  cmd_map["tile"] = tileSubWindows;

  cmd_map["exit"] = exitApplication;
  cmd_map["quit"] = exitApplication;

  return cmd_map;
}

const QHash<QString, TiledEditorCommandHandler> cmd_handlers = generateCommandHandlers();


// --------------------------------------------------------------------------------
// handle command from commandline
// --------------------------------------------------------------------------------

// static const QRegExp whitespace_pattern("\\s+");

bool TiledEditor::handleCommand(const QString & cmd_string)
{
  QString cleaned_cmd = cmd_string.simplified();
  if (cleaned_cmd.isEmpty()) {
    printToConsole(tr(">>"));
    return true;
  } else {
    printToConsole(tr(">> %1").arg(cleaned_cmd));
  }

  QStringList cmd_list = cleaned_cmd.split(" ");
  Q_ASSERT(!cmd_list.isEmpty());

  QString cmd = cmd_list.takeFirst();
  if (cmd_handlers.contains(cmd)) {
    return cmd_handlers[cmd](this, cmd_list);
  }

  const QString msg = tr("invalid command: \"%1\"").arg(cleaned_cmd);
  printToConsole(msg);

  return false;
}

