//
//  PostToAbstractPost.m
//  WordPress
//
//  Created by Jorge Bernal on 2/16/11.
//  Copyright 2011 WordPress. All rights reserved.
//

#import "PostToAbstractPost.h"
#import "AbstractPost.h"

@implementation PostToAbstractPost

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)source 
                                      entityMapping:(NSEntityMapping *)mapping 
                                            manager:(NSMigrationManager *)manager 
                                              error:(NSError **)error
{
	if ([[source valueForKey:@"blogID"] isEqualToString:@"0"]) {
		WPLog(@"! Ignoring post with blog id 0");
		return YES;
	}
	if ([[source valueForKey:@"isLocalDraft"] isEqual:[NSNumber numberWithBool:NO]]) {
		WPLog(@"! Ignoring not local draft post");
		return YES;
	}
	if ([[source valueForKey:@"isAutosave"] isEqual:[NSNumber numberWithBool:YES]]) {
		WPLog(@"! Ignoring autosave");
		return YES;
	}
	NSManagedObjectContext *destMOC = [manager destinationContext];
	NSManagedObject *apost;
	NSError *err = nil;
	NSString *postType = [source valueForKey:@"postType"];
	NSFetchRequest *fetchRequest;
	NSArray *results = nil;
	
	// Local drafts in 2.6 were only related to blogs by blogID, which is 1 in most wporg blogs
	// Let's find if the post has some media attached: media items have blogURL which can help
	fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Media"
                                        inManagedObjectContext:[source managedObjectContext]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"postID == %@", [source valueForKey:@"postID"]]];
	NSArray *mediaItems = [[source managedObjectContext] executeFetchRequest:fetchRequest error:&err];
	if (mediaItems && [mediaItems count] > 0) {
		// We have attachments
		NSManagedObject *media = [mediaItems objectAtIndex:0];
		NSString *blogUrl = [media valueForKey:@"blogURL"];
		blogUrl = [blogUrl stringByReplacingOccurrencesOfString:@"http://" withString:@""];
		if([blogUrl hasSuffix:@"/"])
			blogUrl = [blogUrl substringToIndex:blogUrl.length-1];
		blogUrl = [blogUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

		[fetchRequest release];
		fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:[NSEntityDescription entityForName:@"Blog"
											inManagedObjectContext:destMOC]];
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"url like '*%@*'", blogUrl]];
		results = [destMOC executeFetchRequest:fetchRequest error:&err];
		[fetchRequest release];		
	}
	
	if (!results || [results count] == 0) {
		// No media, let's find every blog that matches blogID
		fetchRequest = [[NSFetchRequest alloc] init];
		[fetchRequest setEntity:[NSEntityDescription entityForName:@"Blog"
											inManagedObjectContext:destMOC]];
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"blogID == %@", [[source valueForKey:@"blogID"] numericValue]]];
		results = [destMOC executeFetchRequest:fetchRequest error:&err];
		[fetchRequest release];		
	}
	
	WPLog(@"* Initiating migration for %@", [source valueForKey:@"postTitle"]);	
	if (results && [results count] > 0) {
		for (NSManagedObject *blog in results) {
			if ([postType isEqualToString:@"page"]) {
				apost = [NSEntityDescription insertNewObjectForEntityForName:@"Page"
													  inManagedObjectContext:destMOC];
			} else {
				apost = [NSEntityDescription insertNewObjectForEntityForName:@"Post"
													  inManagedObjectContext:destMOC];
				[apost setValue:[source valueForKey:@"tags"] forKey:@"tags"];
				NSString *categoriesText = [source valueForKey:@"categories"];
				if (categoriesText && ![categoriesText isEqualToString:@""]) {
					NSArray *categories = [categoriesText componentsSeparatedByString:@", "];
					NSMutableSet *postCategories = [apost mutableSetValueForKey:@"categories"];
					for (NSString *categoryName in categories) {
						NSMutableSet *blogCategories = [blog mutableSetValueForKey:@"categories"];
						NSSet *results = [blogCategories filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"categoryName == %@", categoryName]];
						
						if (results && [results count] > 0) {
							[postCategories addObjectsFromArray:[results allObjects]];
							WPLog(@"** Adding category %@ to post %@", categoryName, [source valueForKey:@"postTitle"]);
						} else {
							WPLog(@"!! Category %@ not found for post %@ in blog %@", categoryName, [source valueForKey:@"postTitle"], [blog valueForKey:@"blogName"]);
						}

					}
					[apost setValue:postCategories forKey:@"categories"];
				}
			}
			[apost setValue:[source valueForKey:@"postTitle"] forKey:@"postTitle"];
			[apost setValue:[source valueForKey:@"content"] forKey:@"content"];
			[apost setValue:[NSNumber numberWithInt:AbstractPostRemoteStatusLocal] forKey:@"remoteStatusNumber"];
			[apost setValue:@"Draft" forKey:@"status"];
			
			[apost setValue:blog forKey:@"blog"];
			
			if (mediaItems && [mediaItems count] > 0) {
				// TODO: Import media items here
				WPLog(@"* TODO: import media items");
			}
			if ([apost validateForInsert:&err]) {
				WPLog(@"* Migrated post %@ for blog %@", [apost valueForKey:@"postTitle"], [blog valueForKey:@"blogName"]);
				[manager associateSourceInstance:source
						 withDestinationInstance:apost
								forEntityMapping:mapping];
			} else {
				WPLog(@"! Failed migrating post %@ for blog %@: %@", [apost valueForKey:@"postTitle"], [blog valueForKey:@"blogName"], [err localizedDescription]);
				if (error) {
					*error = err;
				}
				return NO;
			}			
		}
	} else {
		WPLog(@"! Failed migrating post %@: %@", [source valueForKey:@"postTitle"], [err localizedDescription]);
		WPLog(@"No blog found with id %@", [source valueForKey:@"blogID"]);
		if (error) {
			*error = err;
		}
		return NO;
	}

    return YES;
}

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject*)source 
                                    entityMapping:(NSEntityMapping*)mapping 
                                          manager:(NSMigrationManager*)manager 
                                            error:(NSError**)error
{
    return YES;
}

@end