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

// #include <QtDebug>
#include <QtWidgets>
#include <QKeySequence>

#include "CodeEditor.h"
#include "MDIChild.h"
#include "Util.h"


// --------------------------------------------------------------------------------
// constructor and destructor stuff
// --------------------------------------------------------------------------------

const QString TiledEditor::m_applicationName = TiledEditor::tr("Tiled Editor");

const QString TiledEditor::m_applicationVersion = TiledEditor::tr("v0");

const QString TiledEditor::m_aboutMessage = TiledEditor::tr(
      "The <b>Tiling Text Editor</b> demonstrates text editing "
      "where the documents are organized in a tiled manner");


TiledEditor::TiledEditor() : m_logFile(NULL)
{
  createConsole();

  m_mdiArea = new QMdiArea(this);
  m_mdiArea->setBackground(QBrush("#19232D"));
  m_mdiArea->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOn);
  m_mdiArea->setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOn);
  setCentralWidget(m_mdiArea);
  connect(m_mdiArea, SIGNAL(subWindowActivated(QMdiSubWindow *)), this, SLOT(triggerUpdateMenus()));

  m_windowMapper = new QSignalMapper(this);
  connect(m_windowMapper, SIGNAL(mapped(QWidget *)), this, SLOT(triggerActivateSubWindow(QWidget *)));

  // QScroller::grabGesture(m_mdiArea, QScroller::MiddleMouseButtonGesture);
  m_scroller = new FlickCharm(this);
  m_scroller->activateOn(m_mdiArea);

  // must create actions first
  createActions();  // initializes a bunch of action members

  // then create widgets that associate with actions
  createMenus();
  // createToolBars();
  createStatusBar();

  setWindowTitle(tr("Tiling Text Editor"));
  setUnifiedTitleAndToolBarOnMac(true);
  readSettings();

  triggerUpdateMenus();
}


void TiledEditor::readSettings()
{
  QSettings settings("QtProject", "Tiling Text Editor");
  QPoint pos = settings.value("pos", QPoint(200, 200)).toPoint();
  QSize size = settings.value("size", QSize(400, 400)).toSize();
  move(pos);
  resize(size);
}


void TiledEditor::writeSettings()
{
  QSettings settings("QtProject", "Tiling Text Editor");
  settings.setValue("pos", pos());
  settings.setValue("size", size());
}


void TiledEditor::closeEvent(QCloseEvent * event)
{
  m_mdiArea->closeAllSubWindows();

  if (m_mdiArea->currentSubWindow()) {
    event->ignore();
  } else {
    writeSettings();
    if (m_logFile != NULL) {
      stopSessionLog();
    }
    event->accept();
  }
}


// --------------------------------------------------------------------------------
// initialization stuff
// --------------------------------------------------------------------------------

void TiledEditor::createMenus()
{
  m_fileMenu = menuBar()->addMenu(tr("&File"));
  m_fileMenu->addAction(m_newAction);
  m_fileMenu->addAction(m_openAction);
  m_fileMenu->addAction(m_saveAction);
  m_fileMenu->addAction(m_saveAsAction);
  m_fileMenu->addSeparator();
  // QAction *action = m_fileMenu->addAction(tr("Switch layout direction"));
  // connect(action, SIGNAL(triggered()), this, SLOT(triggerSwitchLayoutDirection()));
  m_fileMenu->addAction(m_exitAction);

  m_editMenu = menuBar()->addMenu(tr("&Edit"));
#ifndef QT_NO_CLIPBOARD
  m_editMenu->addAction(m_cutAction);
  m_editMenu->addAction(m_copyAction);
  m_editMenu->addAction(m_pasteAction);
#endif

  m_windowMenu = menuBar()->addMenu(tr("&Window"));
  triggerUpdateWindowMenu();
  connect(m_windowMenu, SIGNAL(aboutToShow()), this, SLOT(triggerUpdateWindowMenu()));
  m_windowMenu->addSeparator();

  m_helpMenu = menuBar()->addMenu(tr("&Help"));
  m_helpMenu->addAction(m_aboutAction);
  m_helpMenu->addAction(m_aboutQtAction);
  m_helpMenu->addSeparator();
  m_helpMenu->addAction(m_toggleConsole);
}


void TiledEditor::createToolBars()
{
  m_fileToolBar = addToolBar(tr("File"));
  m_fileToolBar->addAction(m_newAction);
  m_fileToolBar->addAction(m_openAction);
  m_fileToolBar->addAction(m_saveAction);
  m_fileToolBar->setMovable(false);

#ifndef QT_NO_CLIPBOARD
  m_editToolBar = addToolBar(tr("Edit"));
  m_editToolBar->addAction(m_cutAction);
  m_editToolBar->addAction(m_copyAction);
  m_editToolBar->addAction(m_pasteAction);
  m_editToolBar->setMovable(false);
#endif
}


void TiledEditor::createStatusBar()
{
  statusBar()->showMessage(tr("Ready"));
}


void TiledEditor::createConsole()
{
  m_consoleDock = new QDockWidget(tr("Debug Console"), this);
  QWidget * new_widget = new QWidget(m_consoleDock);
  QGridLayout * layout = new QGridLayout(new_widget);

  m_consoleOutput = new QTextEdit();
  m_consoleOutput->setReadOnly(true);
  printToConsole("=== Welcome to Tiling Text Editor v0.0 ===\n");
  // qDebug() << tr("=== Welcome to Tiling Text Editor 0 ===");
  layout->addWidget(m_consoleOutput, 0, 0, 1, -1);

  m_consoleInput = new QLineEdit();
  layout->addWidget(m_consoleInput, 1, 0, 1, 1);
  connect(m_consoleInput, SIGNAL(returnPressed()), this, SLOT(triggerExecConsole()));

  QPushButton * enterButton = new QPushButton(tr("Enter"));
  layout->addWidget(enterButton, 1, 1, 1, 1);
  connect(enterButton, SIGNAL(clicked()), this, SLOT(triggerExecConsole()));

  new_widget->setLayout(layout);
  m_consoleDock->setWidget(new_widget);
  // m_consoleDock->setAllowedAreas(Qt::TopDockWidgetArea | Qt::BottomDockWidgetArea);
  m_consoleDock->setAllowedAreas(Qt::BottomDockWidgetArea);
  addDockWidget(Qt::BottomDockWidgetArea, m_consoleDock);
  m_consoleDock->hide();

  // m_toggleConsole = m_consoleDock->toggleViewAction();
  // m_toggleConsole->setShortcut(QKeySequence("CTRL+`"));
}


void TiledEditor::createActions()
{
  m_newAction = new QAction(QIcon(":/images/new.png"), tr("&New"), this);
  m_newAction->setShortcuts(QKeySequence::New);
  m_newAction->setStatusTip(tr("Create a new file"));
  connect(m_newAction, SIGNAL(triggered()), this, SLOT(triggerNewFile()));

  m_openAction = new QAction(QIcon(":/images/open.png"), tr("&Open..."), this);
  m_openAction->setShortcuts(QKeySequence::Open);
  m_openAction->setStatusTip(tr("Open an existing file"));
  connect(m_openAction, SIGNAL(triggered()), this, SLOT(triggerOpen()));

  m_saveAction = new QAction(QIcon(":/images/save.png"), tr("&Save"), this);
  m_saveAction->setShortcuts(QKeySequence::Save);
  m_saveAction->setStatusTip(tr("Save the document to disk"));
  connect(m_saveAction, SIGNAL(triggered()), this, SLOT(triggerSave()));

  m_saveAsAction = new QAction(tr("Save &As..."), this);
  m_saveAsAction->setShortcuts(QKeySequence::SaveAs);
  m_saveAsAction->setStatusTip(tr("Save the document under a new name"));
  connect(m_saveAsAction, SIGNAL(triggered()), this, SLOT(triggerSaveAs()));

  m_exitAction = new QAction(tr("E&xit"), this);
  m_exitAction->setShortcuts(QKeySequence::Quit);
  m_exitAction->setStatusTip(tr("Exit the application"));
  connect(m_exitAction, SIGNAL(triggered()), this, SLOT(triggerExit()));

#ifndef QT_NO_CLIPBOARD
  m_cutAction = new QAction(QIcon(":/images/cut.png"), tr("Cu&t"), this);
  m_cutAction->setShortcuts(QKeySequence::Cut);
  m_cutAction->setStatusTip(tr("Cut the current selection's contents to the "
                               "clipboard"));
  connect(m_cutAction, SIGNAL(triggered()), this, SLOT(triggerCut()));

  m_copyAction = new QAction(QIcon(":/images/copy.png"), tr("&Copy"), this);
  m_copyAction->setShortcuts(QKeySequence::Copy);
  m_copyAction->setStatusTip(tr("Copy the current selection's contents to the clipboard"));
  connect(m_copyAction, SIGNAL(triggered()), this, SLOT(triggerCopy()));

  m_pasteAction = new QAction(QIcon(":/images/paste.png"), tr("&Paste"), this);
  m_pasteAction->setShortcuts(QKeySequence::Paste);
  m_pasteAction->setStatusTip(tr("Paste the clipboard's contents into the current selection"));
  connect(m_pasteAction, SIGNAL(triggered()), this, SLOT(triggerPaste()));
#endif

  m_tileAction = new QAction(tr("&Tile"), this);
  m_tileAction->setStatusTip(tr("Tile the windows"));
  connect(m_tileAction, SIGNAL(triggered()), m_mdiArea, SLOT(tileSubWindows()));

  m_tileVerticalAction = new QAction(tr("Tile Vertically"), this);
  m_tileVerticalAction->setStatusTip(tr("Tile the windows vertically"));
  connect(m_tileVerticalAction, SIGNAL(triggered()), this, SLOT(triggerTileSubWindowsVertically()));

  m_tileHorizontalAction = new QAction(tr("Tile Horizontally"), this);
  m_tileHorizontalAction->setStatusTip(tr("Tile the windows horizontally"));
  connect(m_tileHorizontalAction, SIGNAL(triggered()), this, SLOT(triggerTileSubWindowsHorizontally()));

  m_cascadeAction = new QAction(tr("&Cascade"), this);
  m_cascadeAction->setStatusTip(tr("Cascade the windows"));
  connect(m_cascadeAction, SIGNAL(triggered()), m_mdiArea, SLOT(cascadeSubWindows()));

  m_nextAction = new QAction(tr("Ne&xt"), this);
  m_nextAction->setShortcuts(QKeySequence::NextChild);
  m_nextAction->setStatusTip(tr("Move the focus to the next window"));
  connect(m_nextAction, SIGNAL(triggered()), m_mdiArea, SLOT(activateNextSubWindow()));

  m_previousAction = new QAction(tr("Pre&vious"), this);
  m_previousAction->setShortcuts(QKeySequence::PreviousChild);
  m_previousAction->setStatusTip(tr("Move the focus to the previous window"));
  connect(m_previousAction, SIGNAL(triggered()), m_mdiArea, SLOT(activatePreviousSubWindow()));

  m_closeAction = new QAction(tr("Cl&ose"), this);
  m_closeAction->setStatusTip(tr("Close the active window"));
  connect(m_closeAction, SIGNAL(triggered()), m_mdiArea, SLOT(closeActiveSubWindow()));

  m_closeAllAction = new QAction(tr("Close &All"), this);
  m_closeAllAction->setStatusTip(tr("Close all the windows"));
  connect(m_closeAllAction, SIGNAL(triggered()), m_mdiArea, SLOT(closeAllSubWindows()));

  m_aboutAction = new QAction(tr("&About"), this);
  m_aboutAction->setStatusTip(tr("Show the application's About box"));
  connect(m_aboutAction, SIGNAL(triggered()), this, SLOT(triggerAbout()));

  m_aboutQtAction = new QAction(tr("About &Qt"), this);
  m_aboutQtAction->setStatusTip(tr("Show the Qt library's About box"));
  connect(m_aboutQtAction, SIGNAL(triggered()), qApp, SLOT(aboutQt()));

  m_separatorAction = new QAction(this);
  m_separatorAction->setSeparator(true);

  m_toggleConsole = new QAction(tr("Console"), this);
  m_toggleConsole->setShortcut(QKeySequence("CTRL+`"));
  connect(m_toggleConsole, SIGNAL(triggered()), this, SLOT(triggerToggleConsole()));
}


// --------------------------------------------------------------------------------
// user interactivity things (slots)
// --------------------------------------------------------------------------------

void TiledEditor::triggerNewFile()
{
  handleCommand("new");
}


void TiledEditor::triggerOpen()
{
  QString open_cmd = "open ";
  open_cmd += QFileDialog::getOpenFileName(this);
  handleCommand(open_cmd);
}


void TiledEditor::triggerSave()
{
  MdiChild * child = getActiveMdiChild();
  if (child != NULL) {
    QString save_cmd = "save ";
    save_cmd += child->getID();
    handleCommand(save_cmd);
  }
}


void TiledEditor::triggerSaveAs()
{
  MdiChild * child = getActiveMdiChild();
  if (child != NULL) {
    QString new_filepath = QFileDialog::getSaveFileName(this, tr("Save As"), child->getCurrentFile());
    QString save_cmd = "save ";
    save_cmd += child->getID();
    save_cmd += new_filepath;
    handleCommand(save_cmd);
  }
}


void TiledEditor::triggerTileSubWindowsVertically()
{
  handleCommand("tile v");
}


void TiledEditor::triggerTileSubWindowsHorizontally()
{
  handleCommand("tile h");
}


void TiledEditor::triggerActivateSubWindow(QWidget * widget)
{
  QMdiSubWindow * window = qobject_cast<QMdiSubWindow *>(widget);
  MdiChild * child = qobject_cast<MdiChild *>(window->widget());

  QString activate_cmd = "activate ";
  activate_cmd += child->getID();
  handleCommand(activate_cmd);
}


#ifndef QT_NO_CLIPBOARD
void TiledEditor::triggerCut()
{
  if (getActiveMdiChild() != NULL) {
    getActiveMdiChild()->cut();
  }
}


void TiledEditor::triggerCopy()
{
  if (getActiveMdiChild() != NULL) {
    getActiveMdiChild()->copy();
  }
}


void TiledEditor::triggerPaste()
{
  if (getActiveMdiChild() != NULL) {
    getActiveMdiChild()->paste();
  }
}
#endif


void TiledEditor::triggerAbout()
{
  // decided not to make this a console command
  about();
}


void TiledEditor::triggerUpdateMenus()
{
  bool hasMdiChild = (getActiveMdiChild() != NULL);
  m_saveAction->setEnabled(hasMdiChild);
  m_saveAsAction->setEnabled(hasMdiChild);
#ifndef QT_NO_CLIPBOARD
  m_pasteAction->setEnabled(hasMdiChild);
#endif
  m_closeAction->setEnabled(hasMdiChild);
  m_closeAllAction->setEnabled(hasMdiChild);
  m_tileAction->setEnabled(hasMdiChild);
  m_cascadeAction->setEnabled(hasMdiChild);

  m_tileVerticalAction->setEnabled(hasMdiChild);
  m_tileHorizontalAction->setEnabled(hasMdiChild);

  m_nextAction->setEnabled(hasMdiChild);
  m_previousAction->setEnabled(hasMdiChild);
  m_separatorAction->setVisible(hasMdiChild);

#ifndef QT_NO_CLIPBOARD
  bool hasSelection = (getActiveMdiChild() && getActiveMdiChild()->hasSelection());
  m_cutAction->setEnabled(hasSelection);
  m_copyAction->setEnabled(hasSelection);
#endif
}


void TiledEditor::triggerUpdateWindowMenu()
{
  m_windowMenu->clear();
  m_windowMenu->addAction(m_closeAction);
  m_windowMenu->addAction(m_closeAllAction);
  m_windowMenu->addSeparator();
  m_windowMenu->addAction(m_tileAction);
  m_windowMenu->addAction(m_cascadeAction);

  m_windowMenu->addAction(m_tileVerticalAction);
  m_windowMenu->addAction(m_tileHorizontalAction);

  m_windowMenu->addSeparator();
  m_windowMenu->addAction(m_nextAction);
  m_windowMenu->addAction(m_previousAction);
  m_windowMenu->addAction(m_separatorAction);

  QList<QMdiSubWindow *> windows = m_mdiArea->subWindowList();
  m_separatorAction->setVisible(!windows.isEmpty());

  for (int i = 0; i < windows.size(); ++i) {
    MdiChild * child = qobject_cast<MdiChild *>(windows.at(i)->widget());

    QString text;
    if (i < 9) {
      text = tr("&%1 %2").arg(i + 1).arg(child->getUserFriendlyCurrentFile());
    } else {
      text = tr("%1 %2").arg(i + 1).arg(child->getUserFriendlyCurrentFile());
    }
    QAction * action  = m_windowMenu->addAction(text);
    action->setCheckable(true);
    action->setChecked(child == getActiveMdiChild());
    connect(action, SIGNAL(triggered()), m_windowMapper, SLOT(map()));
    m_windowMapper->setMapping(action, windows.at(i));
  }
}


void TiledEditor::triggerToggleConsole()
{
  if (m_consoleDock->isVisible()) {
    m_consoleDock->hide();
  } else {
    m_consoleDock->show();
    m_consoleInput->setFocus();
  }
}


void TiledEditor::triggerExecConsole()
{
  const QString cmd = m_consoleInput->text();
  handleCommand(cmd);
  m_consoleInput->clear();
  m_consoleInput->setFocus();
}


void TiledEditor::triggerExit()
{
  handleCommand("exit");
}



// --------------------------------------------------------------------------------
// run time things (functions, not slots)
// --------------------------------------------------------------------------------

void TiledEditor::newFile(const QString * filepath)
{
  MdiChild * child = createMdiChild();
  child->newFile(filepath);
  child->show();
}


bool TiledEditor::openFile(const QString & filepath)
{
  if (filepath.isEmpty()) {
    return false;
  }

  QMdiSubWindow * existing = findMdiSubWindow(filepath);
  if (existing) {
    m_mdiArea->setActiveSubWindow(existing);
    return true;
  }

  MdiChild * child = createMdiChild();
  if (child->loadFile(filepath)) {
    statusBar()->showMessage(tr("File loaded"), 2000);
    child->show();
    return true;
  } else {
    child->close();
    return false;
  }
}


bool TiledEditor::saveFile(const QString & filepath, const QString * new_filepath)
{
  MdiChild * child = findMdiChild(filepath);
  if (child == NULL) {
    return false;
  }

  if (new_filepath == NULL) {
    return child->saveFile(filepath);
  } else {
    return child->saveFile(*new_filepath);
  }

  // if (getActiveMdiChild() && getActiveMdiChild()->save())
  //   statusBar()->showMessage(tr("File saved"), 2000);
}


MdiChild * TiledEditor::createMdiChild()
{
  MdiChild * child = new MdiChild;
  m_mdiArea->addSubWindow(child, Qt::FramelessWindowHint);

#ifndef QT_NO_CLIPBOARD
  connect(child, SIGNAL(copyAvailable(bool)), m_cutAction, SLOT(setEnabled(bool)));
  connect(child, SIGNAL(copyAvailable(bool)), m_copyAction, SLOT(setEnabled(bool)));
#endif

  return child;
}


MdiChild * TiledEditor::findMdiChild(const QString & fileName)
{
  QMdiSubWindow * window = findMdiSubWindow(fileName);
  if (window == NULL) {
    return NULL;
  } else {
    return qobject_cast<MdiChild *>(window->widget());
  }
}


QMdiSubWindow * TiledEditor::findMdiSubWindow(const QString & fileName)
{
  QString canonicalFilePath = QFileInfo(fileName).canonicalFilePath();

  foreach(QMdiSubWindow * window, m_mdiArea->subWindowList()) {
    MdiChild * mdiChild = qobject_cast<MdiChild *>(window->widget());
    if (mdiChild->getCurrentFile() == canonicalFilePath)
      return window;
  }

  return NULL;
}


MdiChild * TiledEditor::getActiveMdiChild()
{
  if (QMdiSubWindow * activeSubWindow = m_mdiArea->activeSubWindow())
    return qobject_cast<MdiChild *>(activeSubWindow->widget());
  return 0;
}


// void MainWindow::switchLayoutDirection()
// {
//   if(layoutDirection() == Qt::LeftToRight)
//     qApp->setLayoutDirection(Qt::RightToLeft);
//   else
//     qApp->setLayoutDirection(Qt::LeftToRight);
// }


bool TiledEditor::setActiveSubWindow(const QString & filepath)
{
  QMdiSubWindow * window = findMdiSubWindow(filepath);
  if (window != NULL) {
    m_mdiArea->setActiveSubWindow(window);
    return true;
  } else {
    return false;
  }
}


void TiledEditor::tileSubWindowsVertically()
{
  if (m_mdiArea->subWindowList().isEmpty())
    return;

  QPoint position(0, 0);

  foreach(QMdiSubWindow * window, m_mdiArea->subWindowList()) {
    QRect rect(0, 0, m_mdiArea->width(), m_mdiArea->height() / m_mdiArea->subWindowList().count());
    window->setGeometry(rect);
    window->move(position);
    position.setY(position.y() + window->height());
  }
}


void TiledEditor::tileSubWindowsHorizontally()
{
  if (m_mdiArea->subWindowList().isEmpty())
    return;

  QPoint position(0, 0);

  foreach(QMdiSubWindow * window, m_mdiArea->subWindowList()) {
    QRect rect(0, 0, m_mdiArea->width() / m_mdiArea->subWindowList().count(), m_mdiArea->height());
    window->setGeometry(rect);
    window->move(position);
    position.setX(position.x() + window->width());
  }
}


void TiledEditor::about()
{
  QMessageBox::about(this, tr("About %1 %2").arg(m_applicationName, m_applicationVersion), m_aboutMessage);
}


void TiledEditor::printToConsole(const QString & str, bool newline)
{
  appendText(m_consoleOutput, str);
  if (newline) {
    appendText(m_consoleOutput, "\n");
  }

  if (m_logFile != NULL) {
    fputs(str.toStdString().c_str(), m_logFile);
    if (newline) {
      fputs("\n", m_logFile);
    }
  }
}


bool TiledEditor::startSessionLog(const QString & filename)
{
  if (m_logFile == NULL) {
    m_logFile = fopen(filename.toStdString().c_str(), "wb");
    return true;
  } else {
    return false;
  }
}


bool TiledEditor::stopSessionLog()
{
  if (m_logFile == NULL) {
    return false;
  } else {
    fclose(m_logFile);
    m_logFile = NULL;
    return true;
  }
}


// #define QT_NO_DEBUG_OUTPUT
// #define QT_NO_WARNING_OUTPUT

void TiledEditor::handleSystemMessage(QtMsgType type, const QMessageLogContext & context, const QString & msg)
{
  QString fmt_msg;

  QByteArray localMsg = msg.toLocal8Bit();
  switch (type) {
    case QtDebugMsg:
      fmt_msg.sprintf("[DEBUG] %s (%s:%u, %s)", localMsg.constData(), context.file, context.line, context.function);
      break;
    case QtWarningMsg:
      fmt_msg.sprintf("[WARNING] %s (%s:%u, %s)", localMsg.constData(), context.file, context.line, context.function);
      break;
    case QtCriticalMsg:
      fmt_msg.sprintf("[CRITICAL] %s (%s:%u, %s)", localMsg.constData(), context.file, context.line, context.function);
      break;
    case QtFatalMsg:
      fmt_msg.sprintf("[FATAL] %s (%s:%u, %s)", localMsg.constData(), context.file, context.line, context.function);
  }

  printToConsole(fmt_msg);
}

