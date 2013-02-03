shql
============

**shql** is a program that reads SQL commands interactively and
executes those commands by **creating and manipulating Unix files**.

This program requires a shell that understands functions,
as well as `awk`, `grep`, `cut`, `sort`, `uniq`, `join`, `wc`, 
and `sed`. I'm going to assume your shell has that. 


Usage
----------

This script can be invoked with the command 

```
shql [-q] {database name}
```

**A directory must be created for the database before you may use it**.
This directory will house all data files for a single database.
The directory name should match the database name. Of course, multiple
databases are possible, with different directories.

A database called, for example, 'mydb' may be created as a directory 
as either:

* `$HOME/shql/mydb`
* `./mydb`
* `$SHQL_ROOT/mydb`, where `$SHQL_ROOT` is user-defined.

All datafiles are created with mode 666 (`rw-rw-rw-`), so create the
directory with 777 (`rwxrwxrwx`) if you want the database to be 
sharable, and 700 (`rwx------`) to be private.  

The `-q` option turns off the display of headings so the output of shql 
can be cleanly piped into other programs.

The program is patterned after the ancient and glorious Ingres's 
interactive sql terminal monitor program.  Terminal monitor commands begin 
with either a forward or backward-slash.  Forward slashes may appear at the end of
a command line. Back-slashes are accepted for compatability.  

The `/g` is the 'go' command, `/p` is print, and `/q` is quit.  
Because of this, if you need a slash as the second to last character on a line, 
you should add a space between the slash and the last character.

Try `help commands` for a full list of commands.

To get started, invoke shql with a database name.  Use the directory 
name you created above. Type

```
./shql mydb
```

if the directory you created was 'mydb'.  Once shql starts up, you 
should see the database name displayed, and then a `*`. 

At this point, the most valuable thing is to type `help`:

```
help
```

```
/g
```

You may then go on.  The command `help syntax` displays syntax
for all SQL operations, and 'help commands' displays all shql
workspace commands.  

Try the demo because it is fun:

```
mkdir mydb
./shql mydb < demo.shql
```

**shql** can execute only one operation at a time, but operations can
be spread over several lines. 

Operations
------------

**shql** operations allow `select` operations on multiple tables.
Table names are read from left to write in select's 'from'
section, so the tables should be ordered with the most central
tables first.  In two-table joins, it doesn't matter.  In three
table joins, if you join table A-to-B and B-to-C, B must not be
the last table in the from clause, because shql will not be able
to join tables A-C. If you get the message `Join not found, try
reordering tables`, this is probably the problem.

Qualified field names are not understood, like `tablename.fieldname`,
so if you are joining my_id in table A with my_id in table B, just
say `my_id = my_id`.  Views can also be used to create
multi-table selects.

Subselects are implemented, but must be the last operand of a
`where` clause, most useful with `in`.

In most cases, commas are optional.  `NULL`s are not implemented.
Aggregates like `AVG()` are implemented, but not with `GROUP BY`.

When `INSERT`ing strings that contain the characters `!`, `*`,`=`,
`>`,`<`, `(`, or `)`, spaces or backslashes may be added during 
the insert.  This is a side-effect of the string manipulation 
needed to properly parse the command parameters.

This SQL is type-less, so specify just the column width when creating
tables.  This is used only for display purposes.  **shql** is
case-sensitive, and expects SQL key words to be in lower case.

Unix is a Thing
-----------------

Commands can be piped into shql.  The table data files are
tab delimited, so `awk` scripts can be used to generate reports 
directly from the tables.  To operate on non-shql data files,
create a dummy table with the proper fields, then copy your file
into your shql data directory, replacing your delimiters with
tabs, then run shql on the table, and convert the table back to 
its original format.  

Backticks may be used to execute unix commands (carefully) from with shql. 
Environment variables may also be used. See the demo for an example, 
i.e. `cat demo.shql | shql mydb`.

**shql** was originally written in the early 90's by Bruce Momjian:

Bruce Momjian, root@candle.pha.pa.us

This version of **shql** is maintained by:

Ted Nyman, ted@ted.io
