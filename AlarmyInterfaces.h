/*
 * A header file for all of Alarmy's interfaces
 *
 *
 */

@interface Alarm : NSObject
	- (id) alarmId;
	- (id) alarmID;
@end

@interface AlarmManager : NSObject
	+ (BOOL) isAlarmNotification:(id)arg1;
@end

@interface SBSystemLocalNotificationAlert
	- (id) localNotification;
@end

@interface MoreInfoTableViewCell : UITableViewCell
@end

@interface EditAlarmViewController : UIViewController <UITextFieldDelegate>
	- (Alarm *)alarm;
	- (void) _updateEditAlarmViewFrameWithNotification:(NSNotification *)notification andWillShow:(BOOL)willShow;
@end

@interface EditAlarmView : UIView
@end

@interface UIConcreteLocalNotification
	- (NSDate *)fireDate;
	- (void)setFireDate:(NSDate *)arg1;
	- (NSDictionary *) userInfo;
	- (NSCalendar *)repeatCalendar;
@end
