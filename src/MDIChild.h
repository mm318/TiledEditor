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

#ifndef MDICHILD_H
#define MDICHILD_H

#include <QDialog>
#include <QVBoxLayout>
#include <QTextEdit>


class MdiChild : public QDialog
{
  Q_OBJECT

public:
  MdiChild(QWidget * parent = nullptr);

  // int getID() const { return m_id; }
  const QString & getID() const { return getCurrentFile(); }
  void setWindow(QMdiSubWindow * window) { m_window = window; }

  void newFile(const QString * filepath);
  bool loadFile(const QString & filepath);
  bool saveFile(const QString & filepath);

  void cut() { m_document->cut(); }
  void copy() { m_document->copy(); }
  void paste() { m_document->paste(); }

  bool hasSelection() const { return m_document->textCursor().hasSelection(); }
  const QString & getCurrentFile() const { return m_currentFile; }
  QString getUserFriendlyCurrentFile() const;

protected:
  void keyPressEvent(QKeyEvent * event) override;
  void keyReleaseEvent(QKeyEvent * event) override;
  void mousePressEvent(QMouseEvent * event) override;
  void mouseMoveEvent(QMouseEvent * event) override;
  void closeEvent(QCloseEvent * event) override;

private:
  bool maybeSave();
  void setCurrentFile(const QString & filepath);

private slots:
  void documentWasModified();

private:
  QMdiSubWindow * m_window;
  QVBoxLayout * m_layout;
  QTextEdit * m_document;

  // int m_id;
  bool m_isUntitled;
  QString m_currentFile;

  bool m_moving;
  QPoint m_oldPos;
};

#endif
