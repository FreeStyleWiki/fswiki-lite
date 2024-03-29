#!/bin/sh
##########################################################################
#
# FSWikiLiteリリース用シェルスクリプト
#
##########################################################################
#=========================================================================
# 引数のチェック
#=========================================================================
if [ $# -lt 1 ]
then
  echo "./release.sh version"
  exit 1
fi

#=========================================================================
# バージョン情報
#=========================================================================
VERSION=$1
RELEASE="fswiki_lite_$VERSION"

#=========================================================================
# テンポラリディレクトリがある場合は削除
#=========================================================================
if [ -e $RELEASE ]; then
  echo "delete temp directory..."
  rm -rf $RELEASE
fi

#=========================================================================
# zipファイルがある場合は削除
#=========================================================================
if [ -e $RELEASE.zip ]; then
  echo "delete zip file..."
  rm -f $RELEASE.zip
fi

#=========================================================================
# テンポラリディレクトリの作成
#=========================================================================
echo "create temp directory..."
mkdir $RELEASE

#=========================================================================
# ファイルのコピー
#=========================================================================
echo "copy to temp directory..."
cp ./*.cgi $RELEASE
cp -r ./data $RELEASE
cp -r ./docs $RELEASE
cp -r ./lib $RELEASE
cp -r ./plugin $RELEASE
cp -r ./theme $RELEASE

#=========================================================================
# zipファイルの作成
#=========================================================================
echo "create zip file..."
find ./$RELEASE \! -path '*/CVS*' -exec zip $RELEASE.zip {} \;

#=========================================================================
# テンポラリディレクトリを削除
#=========================================================================
echo "remove temp directory..."
rm -rf $RELEASE

#=========================================================================
# 終了
#=========================================================================
echo "complete."
