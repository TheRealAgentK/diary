//
//  DYNoteStorage.m
//  Diary
//
//  Created by Jon Manning on 6/01/2014.
//  Copyright (c) 2014 Secret Lab. All rights reserved.
//

#import "DYNoteStorage.h"

// Import EventKit so that we can get access to calendar information.
@import EventKit;

// This variable stores the single, shared instance of this class.
static DYNoteStorage* _sharedStorage;

// We're using a class extension to store some private properties.
@interface DYNoteStorage ()

// The following properties are marked as 'nonatomic' because we're overriding their getters.

// The persistent store coordinator manages access to the actual database file itself.
@property (nonatomic) NSPersistentStoreCoordinator* persistentStoreCoordinator;

// The managed object model describes what kinds of objects live in the database.
@property (nonatomic) NSManagedObjectModel* managedObjectModel;

// The managed object context is the 'bag' in which all objects exist.
@property (nonatomic) NSManagedObjectContext* managedObjectContext;

// The event store gives us access to the calendar information.
@property (nonatomic) EKEventStore* eventStore;

@end

@implementation DYNoteStorage {
}

// Returns the single shared instance of the DYNoteStorage class.
+ (DYNoteStorage*) sharedStorage {
    
    // The first time this method is called, the shared instance won't exist.
    // To ensure it's created (and only ever created once), use dispatch_once.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedStorage = [[DYNoteStorage alloc] init];
    });
    
    return _sharedStorage;
}

// Returns the event store.
- (EKEventStore*) eventStore {
    if (_eventStore != nil)
        return _eventStore;
    
    _eventStore = [[EKEventStore alloc] init];
    
    return _eventStore;
}

// Returns the location of the folder where the app can store documents.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

// Returns the managed object model.
- (NSManagedObjectModel*) managedObjectModel {
    
    // If the managed object model has already been created, then just return it.
    if (_managedObjectModel != nil)
        return _managedObjectModel;
    
    NSURL* modelURL = [[NSBundle mainBundle] URLForResource:@"Diary" withExtension:@"momd"];
    
    // ..and then load it.
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    return _managedObjectModel;
    
}

// Returns the managed object context.
- (NSManagedObjectContext *)managedObjectContext {
    
    // If the context has already been created, return it.
    if (_managedObjectContext != nil)
        return _managedObjectContext;
    
    // If it hasn't been created yet, do so now.
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    
    // The managed object context needs to have a persistent store coordinator to work, so do that now.
    // (Note that by calling self.persistentStoreCoordinator, it'll cause one to be created if it didn't already.)
    [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    
    return _managedObjectContext;
}

// Returns the app's persistent store coordinator.
- (NSPersistentStoreCoordinator*) persistentStoreCoordinator {
    
    // Return the coordinator if it's already been created.
    if (_persistentStoreCoordinator != nil)
        return _persistentStoreCoordinator;
    
    // Create the persistent store coordinator. We need to give it the managed object model in order to do so.
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    
    // Work out the location of the database file, by getting the app's document directory and adding
    // 'Diary.sqlite' to the path.
    NSURL* storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Diary.sqlite"];
    
    // Try to add the persistent store.
    NSError* error = nil;
    
    [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
    
    if (error != nil) {
        NSLog(@"Failed to open the store! Error: %@", error);
        _persistentStoreCoordinator = nil;
        return nil;
    }
    
    return _persistentStoreCoordinator;
    
}

// Creates a new note, and adds it to the database.
- (DYNote *)createNote {
    
    // Create the new note, and insert it into the managed object context.
    DYNote* newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    
    // Note text defaults to "New note"
    newNote.text = @"New note";
    
    // Query the calendar, and try to find out if we're creating this note during an event.
    // First, ensure that we have access to the calendar.
    [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError *error) {
        if (granted) {
            // If we have permission, find an appropriate event and prepare the note using that.
            [self prepareNoteWithCalendarEvent:newNote];
        } else {
            // We don't have permission - leave the note as-is.
        }
        
    }];
    
    // Try to save the database, which ensures that the note is stored.
    NSError* error = nil;
    
    [self.managedObjectContext save:&error];
    
    if (error != nil) {
        NSLog(@"Couldn't save the context: %@", error);
        return nil;
    }
    
    // Return the new note.
    return newNote;
}

// Called by createNote, to try to find the event that the note is being created in.
- (void) prepareNoteWithCalendarEvent:(DYNote*)note {

    if ([EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent] != EKAuthorizationStatusAuthorized) {
        // We don't have permission to access the calendar. Give up.
        return;
    }
    
    // We're looking for events that started 6 hours ago, and end 6 hours from now.
    // We'll use NSDateComponents to perform the calculation, because this kind of calculation is _tricky_.
    
    
    // First, get the user's current calendar. (In Western countries, this will probably be Georgian, but could be different.)
    NSCalendar* calendar = [NSCalendar currentCalendar];
    
    // Get the current time.
    NSDate* now = [NSDate date];
    
    // Construct an NSDateComponent that represents "6 hours before".
    NSDateComponents* startOffset = [[NSDateComponents alloc] init];
    [startOffset setHour:-6];
    
    // Construct an NSDateComponent that represents "6 hours after".
    NSDateComponents* endOffset = [[NSDateComponents alloc] init];
    [endOffset setHour:6];
    
    // Get an NSDate that represents 6 hours before now by adding this offset to now.
    NSDate* startDate = [calendar dateByAddingComponents:startOffset toDate:now options:0];
    
    // Get an NSDate that represents 6 hours from now by adding this offset to now.
    NSDate* endDate = [calendar dateByAddingComponents:endOffset toDate:now options:0];
    
    // We now have dates that refer to 6 hours ago and 6 hours from now.    
    // Create a predicate (aka a search query) that finds events within the range of startDate and endDate, on all calendars.
    NSPredicate* predicate = [self.eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
    
    // Find the events.
    NSArray* events = [self.eventStore eventsMatchingPredicate:predicate];
    
    EKEvent* eventToUse = nil;
    
    for (EKEvent* event in events) {
        // If we're in the middle of this event - that is, start time is before now, and end time is after now - then use this event.
        
        if ([event.startDate compare:now] == NSOrderedAscending && // startDate is before now
            [event.endDate compare:now] == NSOrderedDescending) { // endDate is after now
            
            // The event is happening right now! We'll use it.
            eventToUse = event;
            
            // Stop looking for events.
            break;
            
        }
    }
    
    // If we now have an event, grab info from it!
    if (eventToUse) {
        note.text = [NSString stringWithFormat:@"Note created during %@", eventToUse.title];
    } else {
        // We have no event, so just leave the note
    }
    
    // Save the note's changes. This method might be run on a background thread, so to keep things safe, we'll save it
    // on the main operation queue.
    
    // Get the main queue
    NSOperationQueue* mainQueue = [NSOperationQueue mainQueue];
    
    // Schedule the save operation.
    [mainQueue addOperationWithBlock:^{
        NSError* error = nil;
        
        [note.managedObjectContext save:&error];
        
        if (error != nil) {
            NSLog(@"Failed to save the note: %@", error);
        }
    }];
    

}

// Deletes a note from the database.
- (void)deleteNote:(DYNote *)note {
    
    // Delete the note...
    [self.managedObjectContext deleteObject:note];
    
    // ..and save the database.
    NSError* error = nil;
    
    [self.managedObjectContext save:&error];
    
    if (error != nil) {
        NSLog(@"Couldn't save the context: %@", error);
    }
}

// Creates and prepares a fetched results controller which provides info on Note entities.
- (NSFetchedResultsController *)createFetchedResultsController {
    
    // Create a fetch request, which describes what kind of entity we're looking for.
    NSFetchRequest* fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Note"];
    
    fetchRequest.fetchBatchSize = 20;
    
    // Sort the results in order of most recently edited.
    NSSortDescriptor* sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"modifiedDate" ascending:NO];
    
    fetchRequest.sortDescriptors = @[sortDescriptor];
    
    // Create the fetched results controller itself.
    NSFetchedResultsController* newFetchedResultsController =
        [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest // What to look for
                                            managedObjectContext:self.managedObjectContext // Where to find it
                                              sectionNameKeyPath:nil // How to group them (nil = no sections)
                                                       cacheName:nil]; // Where to cache them (nil = no caching)
    
    return newFetchedResultsController;
}

// Returns a note, given its URL in the database.
- (DYNote *)noteWithURL:(NSURL *)url {
    // First, we use the URL to ask the persistent store coordinator for an object ID.
    NSManagedObjectID* objectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
    
    // Next, we get the object with that ID.
    DYNote* note = (DYNote*)[self.managedObjectContext objectRegisteredForID:objectID];
    
    return note;
    
}


@end
