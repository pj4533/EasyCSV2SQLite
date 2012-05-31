EasyCSV2SQLite
===============

Wrote this app last year as a utility to help with some other projects.  Unfortunately, I never really continued developing it, or anything.  I think it could be useful to people, so I figured I'd open source it.

It is still available on the app store if you want to download the binary.  Here is the description:

EasyCSV2SQLite makes it easy to convert comma delimited text files to sqlite databases. The primary use would be to include datasets inside development projects. To further enable this, EasyCSV2SQLite will generate objective-c code necessary to read the created SQLite database.

EasyCSV2SQLite is a very simple application, but does its job well!

- each column is a VARCHAR(255)
- line endings for the CSV file can be LF/CR/CRLF
- first line used as column headers
- objective-c code generated for reading database
- uses NSScanner rather than componentsSeparatedByString so it properly parses commas in quotation marks

The code generation was initially based on code from a blog post at dBlog.com.au. Thanks to them for showing how easy it is to read SQLite from objective-c!

