/****************************************************************************
**
** Copyright (C) 2013 Digia Plc and/or its subsidiary(-ies).
** Contact: http://www.qt-project.org/legal
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** You may use this file under the terms of the BSD license as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of Digia Plc and its Subsidiary(-ies) nor the names
**     of its contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include <QApplication>
#include <QFile>
#include <QStyleFactory>
#include <QDebug>

#include "libs/dropt/droptxx.hpp"

#include "CodeEditor.h"


static TiledEditor * messageHandler = NULL;

void handleMessageOutput(QtMsgType type, const QMessageLogContext & context, const QString & msg)
{
  messageHandler->handleSystemMessage(type, context, msg);
}


int main(int argc, char * argv[])
{
  Q_INIT_RESOURCE(mdi);

  // QFile styleFile(":/qss/DarkMonokai.qss");
  QFile styleFile(":/qss/QDarkStyle.qss");
  styleFile.open(QFile::ReadOnly);
  QString styleSheet(styleFile.readAll());

  /* initializing the Qt application */
  QApplication application(argc, argv);
  application.setApplicationName(TiledEditor::m_applicationName);
  application.setApplicationVersion(TiledEditor::m_applicationVersion);
  // application.setStyle("Plastique");
  application.setStyleSheet(styleSheet);

  /* setting up argument parsing */
  bool showHelp = false;
  bool showVersion = false;
  char * script_name = NULL;
  dropt_option options[] = {
    { 'h',  "help", "shows help.", NULL, dropt::handle_bool, &showHelp, dropt_attr_halt },
    { '?', NULL, NULL, NULL, dropt::handle_bool, &showHelp, dropt_attr_halt | dropt_attr_hidden },
    { 'v', "version", "shows version information.", NULL, dropt::handle_bool, &showVersion, dropt_attr_halt },
    { 's', "script", "executes the given play file", "play file", dropt::handle_string, &script_name, 0},
    { '\0', NULL, NULL, NULL, NULL, NULL, 0 } // Required sentinel value
  };
  dropt::context droptContext(options);

  /* parsing arguments */
  char ** args_rest = NULL;
  if (argc > 0) {
    // qDebug() << argv[0]; // debug
    QTextStream cmdline_out(stdout);
    cmdline_out << argv[0]; // debug
    args_rest = droptContext.parse(&argv[1]);
    if (droptContext.get_error() != dropt_error_none) {
      // qDebug() << TiledEditor::m_applicationName << ": " << droptContext.get_error_message() << endl;
      cmdline_out << TiledEditor::m_applicationName << ": " << droptContext.get_error_message() << endl;
      return EXIT_FAILURE;
    } else if (showHelp) {
      // qDebug() << "Usage: " << TiledEditor::m_applicationName << " [options] [--] [files]\n\n"
      cmdline_out << "Usage: " << TiledEditor::m_applicationName << " [options] [--] [files]\n\n"
               << "Options:\n" << droptContext.get_help().c_str() << endl;
      return EXIT_SUCCESS;
    } else if (showVersion) {
      // qDebug() << TiledEditor::m_applicationName << " " << TiledEditor::m_applicationVersion << endl;
      cmdline_out << TiledEditor::m_applicationName << " " << TiledEditor::m_applicationVersion << endl;
      return EXIT_SUCCESS;
    }
  }

  TiledEditor mainWin;
  messageHandler = &mainWin;
  qInstallMessageHandler(handleMessageOutput);

  mainWin.show();

  qDebug() << "testing debug message handler";

  return application.exec();
}

