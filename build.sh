yacc --verbose --debug -d mongo.y
lex lex.l
gcc lex.yy.c y.tab.c -o out
./out < query.ms
rm lex.yy.c y.tab.c y.tab.h out