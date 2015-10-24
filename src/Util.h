#ifndef UTIL_H
#define UTIL_H

#include <QTextEdit>
#include <QPlainTextEdit>


void setTextBoxHeight(QPlainTextEdit * edit, int nRows);
void appendText(QTextEdit * edit, const QString & str);

#endif
