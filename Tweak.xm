/*
 * Alarmy - a tweak to change the snooze for certain alarms
 * Created by James Emrich (EvilPenguin)
 * 
 * Enjoy (<>..<>)
 *
 */

@interface AlarmManager : NSObject
	 + (BOOL) isAlarmNotification:(id)arg1;
@end

@interface SBSystemLocalNotificationAlert
	- (id) localNotification;
@end

@interface MoreInfoTableViewCell : UITableViewCell
@end

@interface EditAlarmViewController : UIViewController <UITextFieldDelegate>
@end

@interface EditAlarmView : UIView
@end

@interface Alarm : NSObject
	- (id) alarmId;
@end

static NSString* const AlarmyMappingsPath    = @"/Library/Application Support/Alarmy/mappings.plist";
static NSMutableDictionary *alarmMappings    = nil;
static UITextField *textField		     = nil;

static inline NSInteger AlarmySnoozeIntervalForId(NSString *alarmId) {
	NSInteger returnValue = NSNotFound;
	if (alarmId.length > 0) {
		NSDictionary *alarmMappingsDict = [[NSDictionary alloc] initWithContentsOfFile:AlarmyMappingsPath];
		if (alarmMappingsDict != nil) {
			returnValue = ([alarmMappingsDict objectForKey:alarmId] ? [[alarmMappingsDict objectForKey:alarmId] intValue] : NSNotFound);
			[alarmMappingsDict release];
		}
	}

	return returnValue;
}

#pragma mark - == SBApplication Hooks ==

%hook SBApplication

- (void) systemLocalNotificationAlertShouldSnooze:(id)alertNotification {
	SBSystemLocalNotificationAlert *alert = (SBSystemLocalNotificationAlert *)alertNotification;
	UILocalNotification *notification = (UILocalNotification *)[alert localNotification]; 	
	
	if ([objc_getClass("AlarmManager") isAlarmNotification:notification]) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[notification userInfo]];	
		[dict setObject:@(YES) forKey:@"isSnooze"];	
		[notification setUserInfo:dict];
	}

	%orig(alertNotification);
}

- (void) scheduleLocalNotifications:(id)notifications replaceExistingNotifications:(BOOL)replace {
	if (notifications != nil && [notifications count] > 0) {
		for (UILocalNotification *notification in notifications) {
			BOOL shouldSnooze = [notification.userInfo objectForKey:@"isSnooze"] ? [[notification.userInfo objectForKey:@"isSnooze"] boolValue] : NO;
			if (shouldSnooze) {
				NSString *alarmId = [notification.userInfo objectForKey:@"alarmId"];
				NSInteger snoozeInterval = AlarmySnoozeIntervalForId(alarmId); 				
				
				if (snoozeInterval != NSNotFound) {				
					NSInteger minuteOffset = (-9 + snoozeInterval);						
					if (minuteOffset != 0) {	
						NSDateComponents *dateComponent = [[NSDateComponents alloc] init];
						[dateComponent setMinute:minuteOffset]; 
	
						NSCalendar *calendar = notification.repeatCalendar;
						NSDate *date = [calendar dateByAddingComponents:dateComponent toDate:notification.fireDate options:0];
						
						NSLog(@"Alarmy changing fire date %@ to %@", notification.fireDate, date);
						if (date != nil) [notification setFireDate:date];					

						[dateComponent release];
					}
				}
			}
		}
	}

	%orig(notifications, replace);
}

%end

#pragma mark - == EditAlarmViewController Hooks ==

%hook EditAlarmViewController

- (id) initWithAlarm:(id)alarm {
	Protocol *textFieldProtocol = objc_allocateProtocol("UITextFieldDelegate");
	if (!class_addProtocol([self class], textFieldProtocol)) {
		NSLog(@"Alarmy: UITextFieldDelegate not added to EditAlarmViewController");
	}

	[[NSNotificationCenter defaultCenter] addObserver:self
                                         	 selector:@selector(keyboardWillShow:)
                                             	     name:UIKeyboardWillShowNotification
                                           	   object:nil];
	return %orig(alarm);
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig;
}

%new 
- (void) keyboardWillShow:(NSNotification *)notification {
	EditAlarmView *alarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");	
	[UIView animateWithDuration:0.5f
		         animations: ^ (void) {
				 	CGPoint alarmViewPoint = alarmView.frame.origin;
				 	alarmView.frame = CGRectMake(alarmViewPoint.x, alarmViewPoint.y - 245.0f, alarmView.frame.size.width, alarmView.frame.size.height);
			 	 }];
}

%new
 - (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	Alarm *alarm = MSHookIvar<Alarm *>(self, "_alarm");	
	if (alarm != nil) {
		NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
		if (newString.length > 0) [alarmMappings setObject:newString forKey:alarm.alarmId];
		else [alarmMappings removeObjectForKey:alarm.alarmId];
	}
	
	return YES;
}

%new
- (void) donePress:(id)sender {
	if (textField != nil) [textField resignFirstResponder];

	EditAlarmView *alarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
	[UIView animateWithDuration:0.5f
        			 animations: ^ (void) {
                     	CGPoint alarmViewPoint = alarmView.frame.origin;
                        alarmView.frame = CGRectMake(alarmViewPoint.x, alarmViewPoint.y + 245.0f, alarmView.frame.size.width, alarmView.frame.size.height);
                     }];
}

#pragma mark - == Private Methods ==

- (void) _doneButtonClicked:(id)clicked {
	if (![alarmMappings writeToFile:AlarmyMappingsPath atomically:YES]) {
		NSLog(@"Alarmy: Could not write mappings to plist");
	}
	
	%orig(clicked);
}

#pragma mark - == UITableViewDelegate ==

- (NSInteger) tableView:(id)view numberOfRowsInSection:(NSInteger)section {
	NSInteger rows = %orig(view, section);
	if (section == 0x00) rows++;

	return rows;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	MoreInfoTableViewCell *cell = (MoreInfoTableViewCell *)%orig(tableView, indexPath);
	if (indexPath.section == 0x00 && indexPath.row == 0x04) {
		cell.textLabel.text = @"Snooze Interval";
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
		UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, cell.frame.size.width, 35.0f)];
 		toolbar.barStyle = UIBarStyleBlackTranslucent;
		toolbar.barTintColor = [UIColor whiteColor];		

		UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(donePress:)];
		[barButtonItem setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor redColor]} forState:UIControlStateNormal];
		[toolbar setItems:@[flexibleSpace, barButtonItem]];
    		
		textField = [[UITextField alloc] initWithFrame:CGRectMake(140.0f, 0.0f, cell.frame.size.width - 150.0f, cell.frame.size.height)];
		textField.backgroundColor = [UIColor clearColor];
		textField.keyboardType = UIKeyboardTypeDecimalPad;
  		textField.textAlignment = NSTextAlignmentRight;
  		textField.delegate = self;
		textField.inputAccessoryView = toolbar;
		
		Alarm *alarm = MSHookIvar<Alarm *>(self, "_alarm");
		if (alarm != nil) textField.text = [alarmMappings objectForKey:alarm.alarmId];
		[cell.contentView addSubview:textField];
		
		[textField release];
		[barButtonItem release];
		[flexibleSpace release];
		[toolbar release];
	}	

	return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row != 0x04) %orig(tableView, indexPath);
}

%end

%ctor {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	alarmMappings = [[NSMutableDictionary alloc] initWithContentsOfFile:AlarmyMappingsPath];
	if (alarmMappings == nil) alarmMappings = [[NSMutableDictionary alloc] init];
	
	%init;
	[pool drain];
}
