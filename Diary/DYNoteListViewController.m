//
//  DYNoteListViewController.m
//  Diary
//
//  Created by Jon Manning on 3/01/2014.
//  Copyright (c) 2014 Secret Lab. All rights reserved.
//

#import "DYNoteListViewController.h"
#import "DYNote.h"
#import "DYNoteViewController.h"

// This is a 'class extension', which lets you add methods, properties and variables
// to a class without having to put them in the header file, which other classes can see.
// Anything you put in the class extension can only be accessed by this class.
@interface DYNoteListViewController () {
    NSMutableArray* _notes;
}

@end

@implementation DYNoteListViewController

- (void)viewDidLoad {
    
    // Create the array that stores the notes
    _notes = [NSMutableArray array];
    
    // Get the table view's "Edit" button, which will put the table into Edit mode when tapped
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
}

// Returns the number of sections (groups of cells) in the table
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // There is only one section in this table.
    return 1;
}


// Returns the number of rows (cells) in the given section.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    // There's only ever one section, so we don't need to worry about checking the value of 'section'.
    
    // The number of rows is equal to the number of notes we have.
    return [_notes count];
}

// Returns a table view cell for use, which shows the data we want to display.
- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Get a cell to use.
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"NoteCell"];
    
    // Work out which note should be shown in this cell. 
    DYNote* note = _notes[indexPath.row];
    
    // Give the note's text to the cell.
    cell.textLabel.text = note.text;
    
    // Return the cell to the table view, which will then show it.
    return cell;
    
}

// Called when the view controller is about to move to another view controller.
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    // If this is the "showNote" segue, then we're about to segue to the Note View Controller because the user tapped on a table view cell.
    if ([segue.identifier isEqualToString:@"showNote"]) {
        
        // Get the note view controller we're about to move to.
        DYNoteViewController* noteViewController = segue.destinationViewController;
        
        // Get the cell that was tapped on.
        UITableViewCell* cell = sender;
        
        // Work out which row this cell was.
        NSIndexPath* indexPath = [self.tableView indexPathForCell:cell];
        
        // Use that to get the appropriate note.
        DYNote* note = _notes[indexPath.row];
        
        noteViewController.note = note;
    }
}

// Called when the view controller is about to appear.
- (void)viewWillAppear:(BOOL)animated {
    
    // Because the notes might have been changed, make the table view reload all data.
    [self.tableView reloadData];
}

// Called when the user has tapped the Delete button.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // We only want to take action if the edit that was made is a deletion.
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        // Find the note that we're talking about
        DYNote* note = _notes[indexPath.row];
        
        // Remove it from the list of notes
        [_notes removeObject:note];
        
        // Finally, remove the cell.
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
        
    }
}

// Called when the user taps the Add button.
- (IBAction)addNote:(id)sender {
    
    // Create a new, empty note
    DYNote* note = [[DYNote alloc] init];
    
    note.text = @"New note";
    
    // Insert the new note at the start of the array
    [_notes insertObject:note atIndex:0];
    
    // Tell the table view to add a new cell for this note:
    
    // First, create an index path that describes the position of the cell
    
    NSIndexPath* indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    // Now add the row
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
    
}

@end
