#include "Util.h"


void setTextBoxHeight(QPlainTextEdit * edit, int nRows)
{
  QFontMetrics m(edit->font());
  int RowHeight = m.lineSpacing();
  edit->setFixedHeight(nRows * RowHeight);
}

void appendText(QTextEdit * edit, const QString & str)
{
  edit->moveCursor(QTextCursor::End);
  edit->insertPlainText(str);
  edit->moveCursor(QTextCursor::End);
}

