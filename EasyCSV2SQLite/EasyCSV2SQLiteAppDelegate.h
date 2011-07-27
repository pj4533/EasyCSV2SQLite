//
//  EasyCSV2SQLiteAppDelegate.h
//  EasyCSV2SQLite
//
//  Created by Paul James Gray on 7/26/11.
//  Copyright 2011 Say Goodnight Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface EasyCSV2SQLiteAppDelegate : NSObject <NSApplicationDelegate, NSOpenSavePanelDelegate, NSTableViewDataSource, NSTableViewDelegate> {
    NSWindow *window;
    NSMutableArray* columnNames;
    
    NSTextField *csvFile;
    NSTextField *sqliteFile;
    NSTextField *createdTableName;
    NSProgressIndicator *progressBar;
    NSTableView *mainTableView;
    NSPopUpButton *lineEndings;
    NSPanel *codeGenerationPanel;
}
@property (assign) IBOutlet NSTextField *csvFile;
@property (assign) IBOutlet NSTextField *sqliteFile;
@property (assign) IBOutlet NSTextField *createdTableName;
@property (assign) IBOutlet NSProgressIndicator *progressBar;
@property (assign) IBOutlet NSTableView *mainTableView;
@property (assign) IBOutlet NSPopUpButton *lineEndings;
@property (assign) IBOutlet NSPanel *codeGenerationPanel;

@property (assign) IBOutlet NSWindow *window;
- (IBAction)browseClicked:(id)sender;
- (IBAction)chooseClicked:(id)sender;
- (IBAction)goClicked:(id)sender;

@end
