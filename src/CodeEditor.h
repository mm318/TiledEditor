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

#ifndef CODEEDITOR_H
#define CODEEDITOR_H

#include <cstdio>

#include <QMainWindow>
#include <QTextEdit>
#include <QLineEdit>
#include "FlickCharm.h"



////////////////////////////////////////////////////////////////////////////////
// begin forward declarations
QT_BEGIN_NAMESPACE
class QAction;
class QMenu;
class QMdiArea;
class QMdiSubWindow;
class QSignalMapper;
QT_END_NAMESPACE

class TiledEditor;
class MdiChild;
// end forward declarations
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// begin main class declaration
class TiledEditor : public QMainWindow
{
  Q_OBJECT

  ////////////////////////////////////////
  // application related functions
public:
  TiledEditor();
  void handleSystemMessage(QtMsgType type, const QMessageLogContext & context, const QString & msg);
  bool handleCommand(const QString & cmd);

  void newFile(const QString * filepath);
  bool openFile(const QString & filepath);
  bool saveFile(const QString & filepath, const QString * new_filepath = NULL);
  void tileSubWindowsVertically();
  void tileSubWindowsHorizontally();
  bool setActiveSubWindow(const QString & filepath);
  void about();
  void printToConsole(const QString & str, bool newline = true);
  bool startSessionLog(const QString & filename);
  bool stopSessionLog();

protected:
  void closeEvent(QCloseEvent * event) override;

private:
  // helper functions during initialization
  void readSettings();
  void writeSettings();
  void createMenus();
  void createToolBars();
  void createStatusBar();
  void createConsole();
  void createActions();
  // end application related functions
  ////////////////////////////////////////

  ////////////////////////////////////////
  // runtime functions
  MdiChild * createMdiChild();
  MdiChild * getActiveMdiChild();
  MdiChild * findMdiChild(const QString & filepath);
  QMdiSubWindow * findMdiSubWindow(const QString & filepath);
  // end runtime functions
  ////////////////////////////////////////

  ////////////////////////////////////////
  // gui functional stuff
private slots:
  // user active gui functions
  void triggerNewFile();
  void triggerOpen();
  void triggerSave();
  void triggerSaveAs();
  void triggerTileSubWindowsVertically();
  void triggerTileSubWindowsHorizontally();
  // void triggerSwitchLayoutDirection();
  void triggerActivateSubWindow(QWidget * window);
  void triggerToggleConsole();
  void triggerAbout();

  // passive gui functions
#ifndef QT_NO_CLIPBOARD
  void triggerCut();
  void triggerCopy();
  void triggerPaste();
#endif
  void triggerUpdateMenus();
  void triggerUpdateWindowMenu();
  void triggerExecConsole();
  void triggerExit();
  // end gui functional stuff
  ////////////////////////////////////////

  ////////////////////////////////////////
  // class members
public:
  static const QString m_applicationName;
  static const QString m_applicationVersion;
  static const QString m_aboutMessage;

private:
  // gui components
  QMdiArea * m_mdiArea;

  QMenu * m_fileMenu;
  QMenu * m_editMenu;
  QMenu * m_windowMenu;
  QMenu * m_helpMenu;
  QToolBar * m_fileToolBar;
  QToolBar * m_editToolBar;

  QDockWidget * m_consoleDock;
  QTextEdit * m_consoleOutput;
  QLineEdit * m_consoleInput;
  FILE * m_logFile;

  // misc
  QSignalMapper * m_windowMapper;
  FlickCharm * m_scroller;

  // file and editing actions
  QAction * m_newAction;
  QAction * m_openAction;
  QAction * m_saveAction;
  QAction * m_saveAsAction;
#ifndef QT_NO_CLIPBOARD
  QAction * m_cutAction;
  QAction * m_copyAction;
  QAction * m_pasteAction;
#endif

  // tile actions
  QAction * m_cascadeAction;
  QAction * m_tileAction;
  QAction * m_tileVerticalAction;
  QAction * m_tileHorizontalAction;
  QAction * m_nextAction;
  QAction * m_previousAction;

  // extra actions
  QAction * m_aboutAction;
  QAction * m_aboutQtAction;
  QAction * m_toggleConsole;
  QAction * m_execConsole;

  // closing actions
  QAction * m_closeAction;
  QAction * m_closeAllAction;
  QAction * m_exitAction; // exiting the whole application

  QAction * m_separatorAction; // placeholder (dummy) action

  // end class members
  ////////////////////////////////////////
};
// end main class declaration
////////////////////////////////////////////////////////////////////////////////

#endif

