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

#include <QtWidgets>

#include "MDIChild.h"


MdiChild::MdiChild()
{
  setAttribute(Qt::WA_DeleteOnClose);
  setSizeGripEnabled(true);
  setStyleSheet("background-color:#19232D;");

  m_layout = new QVBoxLayout(this);
  m_document = new QTextEdit(this);
  
  // To remove any space between the borders and the QSizeGrip...
  m_layout->setContentsMargins(QMargins());
  // and between the other widget and the QSizeGrip
  m_layout->setSpacing(0);
  m_layout->addWidget(m_document);
  // The QSizeGrip position (here Bottom Right Corner) determines its orientation too
  // m_layout->addWidget(new QSizeGrip(this), 0, Qt::AlignBottom | Qt::AlignRight);

  m_document->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOn);
  m_document->setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOn);

  m_isUntitled = true;
}


void MdiChild::newFile(const QString * filepath)
{
  static int sequenceNumber = 1;

  if (filepath == NULL) {
    m_currentFile = tr("document%1.txt").arg(sequenceNumber++);
  } else {
    m_currentFile = *filepath;
  }

  m_isUntitled = true;
  setWindowTitle(m_currentFile + "[*]");
  setWindowModified(true);
  connect(m_document->document(), SIGNAL(contentsChanged()), this, SLOT(documentWasModified()));
}


bool MdiChild::loadFile(const QString & filepath)
{
  QFile file(filepath);
  if (!file.open(QFile::ReadOnly | QFile::Text)) {
    QMessageBox::warning(this, tr("MDI"), tr("Cannot read file %1:\n%2.").arg(filepath).arg(file.errorString()));
    return false;
  }

  QTextStream in(&file);
  QApplication::setOverrideCursor(Qt::WaitCursor);
  m_document->setPlainText(in.readAll());
  QApplication::restoreOverrideCursor();

  setCurrentFile(filepath);

  connect(m_document->document(), SIGNAL(contentsChanged()), this, SLOT(documentWasModified()));

  return true;
}


QString MdiChild::getUserFriendlyCurrentFile() const
{
  return QFileInfo(m_currentFile).fileName();
}


// bool MdiChild::save()
// {
//   if (m_isUntitled) {
//     return saveAs();
//   } else {
//     return saveFile(m_currentFile);
//   }
// }

// bool MdiChild::saveAs()
// {
//   QString filepath = QFileDialog::getSavefilepath(this, tr("Save As"),
//                      m_currentFile);
//   if (filepath.isEmpty())
//     return false;

//   return saveFile(filepath);
// }


bool MdiChild::saveFile(const QString & filepath)
{
  QFile file(filepath);
  if (!file.open(QFile::WriteOnly | QFile::Text)) {
    QMessageBox::warning(this, tr("MDI"), tr("Cannot write file %1:\n%2.").arg(filepath).arg(file.errorString()));
    return false;
  }

  QTextStream out(&file);
  QApplication::setOverrideCursor(Qt::WaitCursor);
  out << m_document->toPlainText();
  QApplication::restoreOverrideCursor();

  setCurrentFile(filepath);
  return true;
}


void MdiChild::closeEvent(QCloseEvent * event)
{
  if (maybeSave()) {
    event->accept();
  } else {
    event->ignore();
  }
}


void MdiChild::documentWasModified()
{
  setWindowModified(m_document->document()->isModified());
}


bool MdiChild::maybeSave()
{
  if (m_document->document()->isModified()) {
    QMessageBox::StandardButton ret;
    ret = QMessageBox::warning(this, tr("MDI"), tr("'%1' has been modified.\n"
                               "Do you want to save your changes?").arg(getUserFriendlyCurrentFile()),
                               QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel);

    if (ret == QMessageBox::Save) {
      return !m_isUntitled;
    } else if (ret == QMessageBox::Cancel) {
      return false;
    }
  }

  return true;
}


void MdiChild::setCurrentFile(const QString & filepath)
{
  m_currentFile = QFileInfo(filepath).canonicalFilePath();
  m_isUntitled = false;
  m_document->document()->setModified(false);
  setWindowModified(false);
  setWindowTitle(getUserFriendlyCurrentFile() + "[*]");
}

