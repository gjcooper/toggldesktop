//
//  LiteAutoCompleteDataSource.m
//  TogglDesktop
//
//  Created by Indrek Vändrik on 23/02/2018.
//  Copyright © 2018 Alari. All rights reserved.
//

#import "LiteAutoCompleteDataSource.h"

@implementation LiteAutoCompleteDataSource

extern void *ctx;

- (id)initWithNotificationName:(NSString *)notificationName
{
	self = [super init];

	self.orderedKeys = [[NSMutableArray alloc] init];
	self.filteredOrderedKeys = [[NSMutableArray alloc] init];
	self.dictionary = [[NSMutableDictionary alloc] init];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDisplayAutocomplete:)
												 name:notificationName
											   object:nil];
	return self;
}

- (NSString *)completedString:(NSString *)partialString
{
	@synchronized(self)
	{
		for (NSString *text in self.filteredOrderedKeys)
		{
			if ([[text commonPrefixWithString:partialString
									  options:NSCaseInsensitiveSearch] length] == [partialString length])
			{
				return text;
			}
		}
	}
	return @"";
}

- (NSString *)get:(NSString *)key
{
	NSString *object = nil;

	@synchronized(self)
	{
		object = [self.dictionary objectForKey:key];
	}
	return object;
}

- (AutocompleteItem *)itemAtIndex:(NSInteger)row
{
	AutocompleteItem *item;

	@synchronized(self)
	{
		item = [self.filteredOrderedKeys objectAtIndex:row];
	}
	return item;
}

- (void)startDisplayAutocomplete:(NSNotification *)notification
{
	[self performSelectorOnMainThread:@selector(displayAutocomplete:)
						   withObject:notification.object
						waitUntilDone:NO];
}

- (void)displayAutocomplete:(NSMutableArray *)entries
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	@synchronized(self)
	{
		[self.orderedKeys removeAllObjects];
		[self.dictionary removeAllObjects];
		for (AutocompleteItem *item in entries)
		{
			NSString *key = item.Text;
			if ([self.dictionary objectForKey:key] == nil)
			{
				[self.orderedKeys addObject:item];
				[self.dictionary setObject:item forKey:key];
			}
		}

		// self.table.usesDataSource = YES;
		if (self.input.autocompleteTableView.dataSource == nil)
		{
			self.input.autocompleteTableView.dataSource = self;
		}

		[self setFilter:self.currentFilter];
	}
}

- (void)reload
{
	NSAssert([NSThread isMainThread], @"Rendering stuff should happen on main thread");

	[self.input toggleTableView:(int)[self.filteredOrderedKeys count]];
	[self.input.autocompleteTableView reloadData];
}

- (void)findFilter:(NSString *)filter
{
	@synchronized(self)
	{
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		                   // Code that runs async
						   NSMutableArray *filtered = [[NSMutableArray alloc] init];
						   for (int i = 0; i < self.orderedKeys.count; i++)
						   {
							   AutocompleteItem *item = self.orderedKeys[i];
							   NSString *key = item.Text;

							   NSArray *stringArray = [filter componentsSeparatedByString:@" "];
							   if (stringArray.count > 1)
							   {
		                           // Filter is more than 1 word. Let's search for all the words entered.
								   int foundCount = 0;
								   for (int j = 0; j < stringArray.count; j++)
								   {
									   NSString *splitFilter = stringArray[j];

									   if ([key rangeOfString:splitFilter options:NSCaseInsensitiveSearch].location != NSNotFound)
									   {
										   foundCount++;
										   if ([key length] > self.textLength)
										   {
											   self.textLength = [key length];
										   }

										   if (foundCount == stringArray.count)
										   {
											   [filtered addObject:item];
										   }
									   }
								   }
							   }
							   else
							   {
		                           // Single word filter
								   if ([key rangeOfString:filter options:NSCaseInsensitiveSearch].location != NSNotFound)
								   {
									   if ([key length] > self.textLength)
									   {
										   self.textLength = [key length];
									   }
									   [filtered addObject:item];
								   }
							   }
						   }
		                   // NSLog(@" FILTERED: %@", [filtered count]);
						   self.filteredOrderedKeys = filtered;
						   dispatch_sync(dispatch_get_main_queue(), ^{
		                   // This will be called on the main thread,
		                   // when async calls finish
											 [self reload];
										 });
					   });
	}
}

- (void)setFilter:(NSString *)filter
{
	self.textLength = 0;
	@synchronized(self)
	{
		bool lastFilterWasNonEmpty = ((filter == nil || filter.length == 0) && (self.currentFilter != nil && self.currentFilter.length > 0));

		self.currentFilter = filter;
		if (filter == nil || filter.length == 0)
		{
			self.filteredOrderedKeys = [NSMutableArray arrayWithArray:self.orderedKeys];
			if (lastFilterWasNonEmpty)
			{
				[self reload];
			}
			else
			{
				[self.input.autocompleteTableView reloadData];
			}
			return;
		}
		NSString *trimmedFilter = [filter stringByTrimmingCharactersInSet:
								   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
		[self findFilter:trimmedFilter];
	}
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
	NSUInteger result = 0;

	@synchronized(self)
	{
		result = [self.filteredOrderedKeys count];
	}

	// NSLog(@"----- ROWS: %lu", (unsigned long)result);

	return result;
}

@end

