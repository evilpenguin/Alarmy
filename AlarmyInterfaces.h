/*
 * A header file for all of Alarmy's interfaces
 *
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
