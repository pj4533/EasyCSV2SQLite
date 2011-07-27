//
//  EasyCSV2SQLiteAppDelegate.m
//  EasyCSV2SQLite
//
//  Created by Paul James Gray on 7/26/11.
//  Copyright 2011 Say Goodnight Software. All rights reserved.
//

#import "EasyCSV2SQLiteAppDelegate.h"
#import "DDFileReader.h"
#import <sqlite3.h>

@implementation EasyCSV2SQLiteAppDelegate

@synthesize csvFile;
@synthesize sqliteFile;
@synthesize createdTableName;
@synthesize progressBar;
@synthesize mainTableView;
@synthesize lineEndings;
@synthesize window;

- (NSString*)  getDelimiter {
    if ([lineEndings.selectedItem.title isEqualToString:@"CR"]) {
        return @"\r";
    } else if ([lineEndings.selectedItem.title isEqualToString:@"CRLF"]) {
        return @"\r\n";
    } else
        return @"\n";
}

- (NSArray*) columnsFromLine:(NSString*) line {
    NSScanner *scanner = [NSScanner scannerWithString:line];
    [scanner setCharactersToBeSkipped:nil];
    // Get newline character set
    NSMutableCharacterSet *newlineCharacterSet = (id)[NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [newlineCharacterSet formIntersectionWithCharacterSet:[[NSCharacterSet whitespaceCharacterSet] invertedSet]];
    
    // Characters that are important to the parser
    NSMutableCharacterSet *importantCharactersSet = (id)[NSMutableCharacterSet characterSetWithCharactersInString:@",\""];
    [importantCharactersSet formUnionWithCharacterSet:newlineCharacterSet];
    
    BOOL insideQuotes = NO;
    BOOL finishedRow = NO;
    NSMutableArray *columns = [NSMutableArray arrayWithCapacity:[columnNames count]];
    NSMutableString *currentColumn = [NSMutableString string];
    while ( !finishedRow ) {
        NSString *tempString;
        if ( [scanner scanUpToCharactersFromSet:importantCharactersSet intoString:&tempString] ) {
            [currentColumn appendString:tempString];
        }
        
        if ( [scanner isAtEnd] ) {
            if ( ![currentColumn isEqualToString:@""] ) [columns addObject:currentColumn];
            finishedRow = YES;
        }
        else if ( [scanner scanCharactersFromSet:newlineCharacterSet intoString:&tempString] ) {
            if ( insideQuotes ) {
                // Add line break to column text
                [currentColumn appendString:tempString];
            }
            else {
                // End of row
                if ( ![currentColumn isEqualToString:@""] ) [columns addObject:currentColumn];
                finishedRow = YES;
            }
        }
        else if ( [scanner scanString:@"\"" intoString:NULL] ) {
            if ( insideQuotes && [scanner scanString:@"\"" intoString:NULL] ) {
                // Replace double quotes with a single quote in the column string.
                [currentColumn appendString:@"\""]; 
            }
            else {
                // Start or end of a quoted string.
                insideQuotes = !insideQuotes;
            }
        }
        else if ( [scanner scanString:@"," intoString:NULL] ) {  
            if ( insideQuotes ) {
                [currentColumn appendString:@","];
            }
            else {
                // This is a column separating comma
                currentColumn = [NSMutableString stringWithString:[currentColumn stringByReplacingOccurrencesOfString:@"'" withString:@""]];
                [columns addObject:currentColumn];
                currentColumn = [NSMutableString string];
                [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
            }
        }
    }

    return columns;
}

- (void) createTable:(NSString*) tableName inDB:(sqlite3*) db fromFilePath:(NSString*) pathToFile {
    
    columnNames = [[NSMutableArray alloc] init];
    
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:pathToFile];
    reader.lineDelimiter = [self getDelimiter];
    NSString * line = [reader readLine];
    [reader release];
    
    
    NSString* sqlStatement = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (", tableName];
    
    NSArray* columns = [self columnsFromLine:line];
    int count = 0;
    for (NSString* thisStr in columns) {
        if (count < [columns count]) {
            thisStr = [thisStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            thisStr = [thisStr stringByReplacingOccurrencesOfString:@" " withString:@"_"];
            
            sqlStatement = [sqlStatement stringByAppendingFormat:@"%@ VARCHAR(255)", thisStr];
            [columnNames addObject:thisStr];
            count++;
            if (count < ([columns count])) {
                sqlStatement = [sqlStatement stringByAppendingString:@", "];
            }            
        }
    }
    sqlStatement = [sqlStatement stringByAppendingString:@");"];
    
//    NSLog(@"tablecreate: %@", sqlStatement);
    
    if(sqlite3_exec(db, [sqlStatement UTF8String], NULL, NULL, NULL) != SQLITE_OK) { 
        sqlite3_close(db);
        NSAssert1(0, @"Error creating table: %s",sqlite3_errmsg(db));
        return; 
    }
}

- (void) addLinesToDB:(sqlite3*) db fromFilePath:(NSString*) pathToFile  fromTableName:(NSString*) tableName{
    
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:pathToFile];
    reader.lineDelimiter = [self getDelimiter];
    [progressBar setMinValue:0];
    [progressBar setMaxValue:[reader totalFileLength]];
    [progressBar setUsesThreadedAnimation:YES];
    [progressBar startAnimation:self];

    NSString * line = nil;
    [reader readLine];
    while ((line = [reader readLine])) {

        
        NSArray* columns = [self columnsFromLine:line];
        
        NSString* sqlStatement = [NSString stringWithFormat:@"INSERT INTO %@(", tableName];
        
        int count = 0;
        for (NSString* thisColumnName in columnNames) {
            sqlStatement = [sqlStatement stringByAppendingFormat:@"%@", thisColumnName];            
            count++;
            if (count < ([columnNames count])) {
                sqlStatement = [sqlStatement stringByAppendingString:@","];
            }
        }
        
        sqlStatement = [sqlStatement stringByAppendingString:@") VALUES("];
        
        count = 0;
        for (NSString* thisValue in columns) {
            thisValue = [thisValue stringByReplacingOccurrencesOfString:@"'" withString:@""];
            sqlStatement = [sqlStatement stringByAppendingFormat:@"'%@'", thisValue];            
            count++;
            if (count < ([columns count])) {
                sqlStatement = [sqlStatement stringByAppendingString:@","];
            }
        }
        
        sqlStatement = [sqlStatement stringByAppendingString:@");"];
        
        sqlite3_stmt *statement;
        if (sqlite3_prepare_v2(db, [sqlStatement UTF8String], -1, &statement, nil) == SQLITE_OK) {
            if (sqlite3_step(statement) == SQLITE_DONE){
                sqlite3_finalize(statement);
            }
        }
        else {
            NSLog(@"%@", sqlStatement);
            NSAssert1(0, @"Error while inserting data. '%s'", sqlite3_errmsg(db));
        }
        
        [progressBar setDoubleValue:[reader currentOffset]];
    }    
    [progressBar stopAnimation:self];
    
    NSRunAlertPanel(@"Done!", @"Successfully Created SQLite Database.", nil, nil, nil);
    
    [reader release];


}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (void) initializeTable {
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:[csvFile stringValue]];
    reader.lineDelimiter = [self getDelimiter];
    NSString * line = [reader readLine];
    [reader release];
    
    
    NSMutableArray* columnsToDel = [[NSMutableArray alloc] initWithCapacity:[[mainTableView tableColumns] count]];
    for (NSTableColumn* thisColumn in [mainTableView tableColumns]) {
        [columnsToDel addObject:thisColumn];
    }
    for (NSTableColumn* thisColumn in columnsToDel) {
        [mainTableView removeTableColumn:thisColumn];
    }
    [columnsToDel release];
    
    int columnIndex = 0;
    NSArray* columns = [self columnsFromLine:line];
    for (NSString* thisStr in columns) {
        thisStr = [thisStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        thisStr = [thisStr stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        
        NSTableColumn* thisColumn = [[NSTableColumn alloc] initWithIdentifier:[NSString stringWithFormat:@"%d",columnIndex]];
        [thisColumn.headerCell setStringValue:thisStr];
        [thisColumn setWidth: (mainTableView.frame.size.width / [columns count])  ];
        [mainTableView addTableColumn:thisColumn];
        columnIndex++;
    }

    [mainTableView reloadData];
}

- (IBAction)browseClicked:(id)sender {
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    [openDlg setDelegate:self];
    
    NSArray* fileTypes = [NSArray arrayWithObjects:@"csv", @"CSV", nil];
    [openDlg setAllowedFileTypes:fileTypes];
    [openDlg setAllowsOtherFileTypes:NO];

    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowsMultipleSelection:NO];
    
    // Display the dialog.  If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSOKButton ) {

        NSURL* pathURL = [[openDlg URLs] objectAtIndex:0];
        NSString* pathString = [pathURL path];
        [csvFile setStringValue:pathString];
        [self initializeTable];
    }
}

- (IBAction)chooseClicked:(id)sender {
    NSSavePanel* saveDlg = [NSSavePanel savePanel];
    [saveDlg setDelegate:self];
    [saveDlg setTitle:@"Save SQLite Database"];
    
    NSArray* fileTypes = [NSArray arrayWithObjects:@"sqlite", @"SQL", @"sql", nil];
    [saveDlg setAllowedFileTypes:fileTypes];
    [saveDlg setAllowsOtherFileTypes:NO];
    
    if ( [saveDlg runModal] == NSFileHandlingPanelOKButton ) {
        NSString* pathString = [[saveDlg URL] path];
        [sqliteFile setStringValue:pathString];
    }
    
}

- (IBAction)goClicked:(id)sender {
    sqlite3 *newDBconnection;
    NSString* pathToCSV = [csvFile stringValue];
    NSString* pathToSqlite = [sqliteFile stringValue];
    NSString* tableName = [createdTableName stringValue];
    
    if ([pathToCSV isEqualToString:@""]) {
        NSRunAlertPanel(@"Error", @"Invalid CSV Path", nil, nil, nil);
        return;
    }
    if ([pathToSqlite isEqualToString:@""]) {
        NSRunAlertPanel(@"Error", @"Invalid sqlite Path", nil, nil, nil);
        return;
    }
    if ([tableName isEqualToString:@""]) {
        NSRunAlertPanel(@"Error", @"Invalid table name", nil, nil, nil);
        return;
    }
    
    
    // XXX ERROR CHECK HERE
    // NSRunAlertPanel(@"Error", @"aewp error", nil, nil, nil);
    
    // Open the database. The database was prepared outside the application.
    if (sqlite3_open([pathToSqlite UTF8String], &newDBconnection) == SQLITE_OK) {
        
        [self createTable:tableName inDB:newDBconnection fromFilePath:pathToCSV];
        [self addLinesToDB:newDBconnection fromFilePath:pathToCSV fromTableName:tableName];
        sqlite3_close(newDBconnection);
    } else {
        NSLog(@"Error in opening db file.");        
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return 20;
}

- (BOOL) tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return NO;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:[csvFile stringValue]];
    reader.lineDelimiter = [self getDelimiter];
    
    [reader readLine];
    int index = 0;
    while ((index < rowIndex) && (reader.currentOffset < reader.totalFileLength)) {
        [reader readLine];
        index++;
    }
    
    if (reader.currentOffset < reader.totalFileLength) {
        NSString * line = [reader readLine];
        [reader release];
        
        
        
        NSArray* columns = [self columnsFromLine:line];
        int columnIndex = [[aTableColumn identifier] intValue];
        NSString* thisStr = [columns objectAtIndex:columnIndex]; 
        
        return thisStr;
    } else
        return @"";
}



@end
