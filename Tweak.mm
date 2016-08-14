/*
 * Alarmy - a tweak to change the snooze for certain alarms
 * Created by James Emrich (EvilPenguin)
 * Version: 0.7.2
 *
 * Enjoy (<>..<>)
 *
 */

#import "AlarmyInterfaces.h"

#define AlarmyMappingsPath      [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Preferences/in.evilpengu.alarmy.plist"]
static UITextField *_textField  = nil;

#pragma mark - == Alarmy Private Functions ==

__unused static NSInteger AlarmySnoozeIntervalForId(NSString *alarmId) {
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

__unused static void AlarmySaveIntervalSettings(NSString *interval, NSString *alarmId) {
    if (alarmId.length > 0) {
        NSMutableDictionary *alarmMappings = [[NSMutableDictionary alloc] initWithContentsOfFile:AlarmyMappingsPath];
        if (alarmMappings == nil) alarmMappings = [[NSMutableDictionary alloc] init];

        if (interval.length > 0) [alarmMappings setObject:interval forKey:alarmId];
        else [alarmMappings removeObjectForKey:alarmId];

        // Save the dictionary to the file system
        if (![alarmMappings writeToFile:AlarmyMappingsPath atomically:YES]) {
            NSLog(@"Alarmy: Could not write mappings to plist");
        }   

        [alarmMappings release];
    }
}

__unused static UIConcreteLocalNotification *AlarmyModifySnoozeNotification(UIConcreteLocalNotification *notification) {
    NSDictionary *userInfo = notification.userInfo;
    if (userInfo.count > 0) {
        NSInteger snoozeInterval = AlarmySnoozeIntervalForId(userInfo[@"alarmId"]);
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

    return notification;
}

#pragma mark - == UNLocalNotificationClient Hooks ==

%hook UNLocalNotificationClient

- (void) scheduleSnoozeNotification:(UIConcreteLocalNotification *)notification {
    notification = AlarmyModifySnoozeNotification(notification);
    %orig(notification);
}

%end

#pragma mark - == AlarmManager Hooks ==

%hook AlarmManager 

- (void) removeAlarm:(Alarm *)alarm {
    AlarmySaveIntervalSettings(nil, alarm.alarmID);
    %orig;
}

- (void) setAlarm:(Alarm *)alarm active:(BOOL)active {
    AlarmySaveIntervalSettings(_textField.text, alarm.alarmID);
    %orig;
}

- (void) updateAlarm:(Alarm *)alarm active:(BOOL)active {
    AlarmySaveIntervalSettings(_textField.text, alarm.alarmID);
    %orig;
}

%end

#pragma mark - == EditAlarmViewController Hooks ==

%hook EditAlarmViewController

- (void) viewWillAppear:(BOOL)animated {
    %orig(animated);

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(_keyboardWillShow:)
                   name:UIKeyboardWillShowNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(_keyboardWillHide:)
                   name:UIKeyboardWillHideNotification
                 object:nil];
    
}

- (void) viewWillDisappear:(BOOL)animated {
    %orig(animated);

    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - == Private New Methods ==

%new 
- (void) _keyboardWillShow:(NSNotification *)notification {
    EditAlarmView *alarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");	
    [UIView animateWithDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]
                     animations: ^ (void) {
                        CGPoint alarmViewPoint = alarmView.frame.origin;
                        alarmView.frame = CGRectMake(alarmViewPoint.x, alarmViewPoint.y - 245.0f, alarmView.frame.size.width, alarmView.frame.size.height);
                    }];
}

%new
- (void) _keyboardWillHide:(NSNotification *)notification {
    EditAlarmView *alarmView = MSHookIvar<EditAlarmView *>(self, "_editAlarmView");
    [UIView animateWithDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]
                     animations: ^ (void) {
                        CGPoint alarmViewPoint = alarmView.frame.origin;
                        alarmView.frame = CGRectMake(alarmViewPoint.x, alarmViewPoint.y + 245.0f, alarmView.frame.size.width, alarmView.frame.size.height);
                     }];
}

%new
- (void) _donePress:(id)sender {
    if (_textField != nil) [_textField resignFirstResponder];    
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

        UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, cell.bounds.size.width, 35.0f)];
        toolbar.barStyle = UIBarStyleBlackTranslucent;
        toolbar.barTintColor = [UIColor whiteColor];		

        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_donePress:)];
        [barButtonItem setTitleTextAttributes:@{NSForegroundColorAttributeName:[UIColor redColor]} forState:UIControlStateNormal];
        [toolbar setItems:@[flexibleSpace, barButtonItem]];

        _textField = [[UITextField alloc] initWithFrame:CGRectMake((tableView.bounds.size.width - 150.0f) - 15.0f, 0.0f, 150.0f, cell.bounds.size.height)];
        _textField.backgroundColor = [UIColor clearColor];
        _textField.keyboardType = UIKeyboardTypeDecimalPad;
        _textField.textAlignment = NSTextAlignmentRight;
        _textField.delegate = self;
        _textField.inputAccessoryView = toolbar;
        _textField.textColor = [UIColor lightGrayColor];
        [cell.contentView addSubview:_textField];

        Alarm *alarm = self.alarm;
        if (alarm != nil) {
            NSInteger interval = AlarmySnoozeIntervalForId(alarm.alarmID);
            _textField.text =  (interval != NSNotFound ? [NSString stringWithFormat:@"%li", (long)interval] : nil);
        }

        [_textField release];
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

#pragma mark - == Dylib Constructor ==

%ctor {
    @autoreleasepool {
        NSLog(@"Loading Alarmy");
        %init;
    }
}
