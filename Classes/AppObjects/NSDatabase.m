//
//  NSDatabase.m
//  linphone
//
//  Created by admin on 11/11/17.
//
//

#import "NSDatabase.h"
#import "KHistoryCallObject.h"
#import "CallHistoryObject.h"
#import "PhoneBookObject.h"
#import "PBXContact.h"
#import "NSData+Base64.h"
#import <MediaPlayer/MediaPlayer.h>
#import "contactBlackListCell.h"
#import "FriendRequestedObject.h"

static sqlite3 *db = nil;

LinphoneAppDelegate *appDelegate;
HMLocalization *localization;

@implementation NSDatabase

+ (BOOL)connectToDatabase {
    appDelegate = (LinphoneAppDelegate *)[[UIApplication sharedApplication] delegate];
    localization = [HMLocalization sharedInstance];
    
    if (appDelegate._databasePath.length > 0) {
        appDelegate._database = [[FMDatabase alloc] initWithPath: appDelegate._databasePath];
        if ([appDelegate._database open]) {
            return YES;
        }else{
            return NO;
        }
    }else{
        return NO;
    }
}

+ (int)getUnreadMissedCallHisotryWithAccount: (NSString *)account {
    int result = 0;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT COUNT(*) as numMissedCall FROM history WHERE my_sip = '%@' and status = '%@' and unread = %d", account, @"Missed", 1];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        result = [[rsDict objectForKey:@"numMissedCall"] intValue];
    }
    [rs close];
    return result;
}

//  reset missed call with remote on date
+ (BOOL)resetMissedCallOfRemote: (NSString *)remote onDate: (NSString *)date ofAccount: (NSString *)account
{
    NSString *tSQL = [NSString stringWithFormat:@"UPDATE history SET unread = %d WHERE my_sip = '%@' AND date = '%@'", 0, account, date];
    return [appDelegate._database executeUpdate: tSQL];
}

// Get tất cả các section trong của history call của 1 user
+ (NSMutableArray *)getHistoryCallListOfUser: (NSString *)account isMissed: (BOOL)missed {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    //  NSString *tSQL = [NSString stringWithFormat:@"SELECT date FROM history WHERE my_sip = '%@' GROUP BY date ORDER BY _id DESC", account];
    NSString *tSQL = [NSString stringWithFormat:@"SELECT date FROM history WHERE my_sip = '%@' GROUP BY date ORDER BY time_int DESC", account];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        NSString *dateStr = [rsDict objectForKey:@"date"];
        
        // Dict chứa dữ liệu cho từng ngày
        NSMutableDictionary *oneDateDict = [[NSMutableDictionary alloc] init];
        [oneDateDict setObject:dateStr forKey:@"title"];
        if (missed) {
            NSMutableArray *missedArr = [self getMissedCallListOnDate:dateStr ofUser:account];
            if (missedArr.count > 0) {
                [oneDateDict setObject:missedArr forKey:@"rows"];
                [result addObject: oneDateDict];
            }
        }else{
            NSMutableArray *callArray = [self getAllCallOnDate:dateStr ofUser:account];
            if (callArray.count > 0) {
                [oneDateDict setObject:callArray forKey:@"rows"];
                [result addObject: oneDateDict];
            }
        }
    }
    [rs close];
    return result;
}

// Get danh sách các cuộc gọi nhỡ
+ (NSMutableArray *)getMissedCallListOnDate: (NSString *)dateStr ofUser: (NSString *)account {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    NSString *tSQL = [NSString stringWithFormat:@"SELECT * FROM history WHERE my_sip = '%@' AND call_direction = 'Incomming' AND status = 'Missed' AND date = '%@' GROUP BY phone_number ORDER BY _id DESC", account, dateStr];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        KHistoryCallObject *aCall = [[KHistoryCallObject alloc] init];
        int callId        = [[rsDict objectForKey:@"_id"] intValue];
        NSString *status        = [rsDict objectForKey:@"status"];
        NSString *phoneNumber = [rsDict objectForKey:@"phone_number"];
        
        NSString *callDirection = [rsDict objectForKey:@"call_direction"];
        NSString *callTime      = [rsDict objectForKey:@"time"];
        NSString *callDate      = [rsDict objectForKey:@"date"];
        
        PhoneObject *contact = [ContactUtils getContactPhoneObjectWithNumber: phoneNumber];
        
        aCall._callId = callId;
        aCall._status = status;
        aCall._prefixPhone = @"";
        aCall._phoneNumber = phoneNumber;
        aCall._callDirection = callDirection;
        aCall._callTime = callTime;
        aCall._callDate = callDate;
        aCall._phoneName = contact.name;
        aCall._phoneAvatar = contact.avatar;
        aCall.newMissedCall = [self getMissedCallUnreadWithRemote:phoneNumber onDate:dateStr ofAccount:account];
        
        [result addObject: aCall];
    }
    return result;
}

// Get danh sách cho từng section call của user
+ (NSMutableArray *)getAllCallOnDate: (NSString *)dateStr ofUser: (NSString *)account {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    //  NSString *tSQL = [NSString stringWithFormat:@"SELECT * FROM history WHERE my_sip = '%@' AND date = '%@' GROUP BY phone_number ORDER BY _id DESC", account, dateStr];
    NSString *tSQL = [NSString stringWithFormat:@"SELECT * FROM history WHERE my_sip = '%@' AND date = '%@' GROUP BY phone_number ORDER BY time_int DESC", account, dateStr];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        KHistoryCallObject *aCall = [[KHistoryCallObject alloc] init];
        int callId        = [[rsDict objectForKey:@"_id"] intValue];
        NSString *status        = [rsDict objectForKey:@"status"];
        NSString *callDirection = [rsDict objectForKey:@"call_direction"];
        NSString *callTime      = [rsDict objectForKey:@"time"];
        NSString *callDate      = [rsDict objectForKey:@"date"];
        NSString *phoneNumber   = [rsDict objectForKey:@"phone_number"];
        long timeInt   = [[rsDict objectForKey:@"time_int"] longValue];
        
        aCall._prefixPhone = @"";
        aCall._phoneNumber = phoneNumber;
        
        //  [Khai le - 03/11/2018]
        PhoneObject *aPhone = [ContactUtils getContactPhoneObjectWithNumber: phoneNumber];
        aCall._callId = callId;
        aCall._status = status;
        aCall._callDirection = callDirection;
        aCall._callTime = callTime;
        aCall._callDate = callDate;
        aCall._phoneName = aPhone.name;
        aCall._phoneAvatar = aPhone.avatar;
        aCall.duration = [[rsDict objectForKey:@"duration"] intValue];
        aCall.timeInt = timeInt;
        aCall.newMissedCall = [self getMissedCallUnreadWithRemote:phoneNumber onDate:dateStr ofAccount:account];
        
        [result addObject: aCall];
    }
    [rs close];
    return result;
}

+ (int)getMissedCallUnreadWithRemote: (NSString *)remote onDate: (NSString *)date ofAccount: (NSString *)account {
    int result = 0;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT COUNT(*) as numMissedCall FROM history WHERE my_sip = '%@' and status = '%@' and unread = %d and date = '%@'", account, @"Missed", 1, date];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        result = [[rsDict objectForKey:@"numMissedCall"] intValue];
    }
    [rs close];
    return result;
}

//  Delete call history of remote on date
+ (BOOL)deleteCallHistoryOfRemote: (NSString *)remote onDate: (NSString *)date ofAccount: (NSString *)account {
    NSString *tSQL = [NSString stringWithFormat:@"DELETE FROM history WHERE my_sip = '%@' and phone_number = '%@' and date = '%@'", account, remote, date];
    BOOL result = [appDelegate._database executeUpdate: tSQL];
    return result;
}

+ (void)InsertHistory : (NSString *)call_id status : (NSString *)status phoneNumber : (NSString *)phone_number callDirection : (NSString *)callDirection recordFiles : (NSString*) record_files duration : (int)duration date : (NSString *)date time : (NSString *)time time_int : (int)time_int rate : (float)rate sipURI : (NSString*)sipUri MySip : (NSString *)mysip kCallId: (NSString *)kCallId andFlag: (int)flag andUnread: (int)unread{
    [self openDB];
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO history(call_id,status,phone_number,call_direction,record_files,duration,date,rate,sipURI,time,time_int,my_sip, k_call_id, flag, unread) VALUES ('%@','%@','%@','%@','%@',%d,'%@',%f,'%@','%@',%d,'%@','%@',%d,%d)",call_id,status,phone_number,callDirection,record_files,duration,date,rate,sipUri,time,time_int,mysip, kCallId, flag, unread];
    NSLog(@"%@",sql);
    char *err;
    sqlite3_exec(db, [sql UTF8String], NULL, NULL, &err);
    sqlite3_close(db);
}












+ (void)openDB {
    int result = sqlite3_open([[self filePath] UTF8String], &db);
    if (sqlite3_open([[self filePath] UTF8String], &db) != SQLITE_OK ) {
        //        char *errMsg;
        //
        //        const char *sql_stmt = "CREATE TABLE IF NOT EXISTS \"history\" (\"_id\" INTEGER PRIMARY KEY  NOT NULL ,\"call_id\" TEXT,\"status\" TEXT,\"phone_number\" TEXT,\"call_direction\" TEXT,\"record_files\" TEXT,\"duration\" INTEGER,\"date\" TEXT DEFAULT (null) ,\"rate\" INTEGER,\"sipURI\" TEXT,\"time\" TEXT, \"time_int\" INTEGER, \"my_sip\" TEXT)";
        //
        //        if (sqlite3_exec(db, sql_stmt, NULL, NULL, &errMsg) != SQLITE_OK)
        //        {
        //            NSLog(@"Failed to create table");
        //        }
        NSLog(@"%d", result);
        NSLog(@"Khong mo duoc database.....");
        sqlite3_close(db);
    }
}

+ (void)closeDB {
    sqlite3_close(db);
}

+(NSString *) filePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = [paths objectAtIndex:0];
    return [documentsDir stringByAppendingPathComponent:@"callnex.sqlite"];
}

<<<<<<< HEAD
=======
+ (NSArray *)getNameAndAvatarOfContactWithPhoneNumber: (NSString *)phonenumber
{
    NSString *fullName = @"";
    NSString *avatar = @"";
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"_sipPhone == %@", phonenumber];
    NSArray *filter = [appDelegate.listContacts filteredArrayUsingPredicate: predicate];
    if (filter.count > 0) {
        ContactObject *aContact = [filter objectAtIndex: 0];
        fullName = aContact._fullName;
        avatar = aContact._avatar;
    }else{
        //  get name pbx truoc
        PBXContact *pbxContact = [AppUtils getPBXContactFromListWithPhoneNumber: phonenumber];
        if (pbxContact != nil) {
            if ([pbxContact._name isEqualToString:@""]) {
                NSString *stringValue = [appDelegate._allPhonesDict objectForKey: phonenumber];
                if (![stringValue isEqualToString:@""]) {
                    NSArray *tmpArr = [stringValue componentsSeparatedByString:@"|"];
                    if (tmpArr.count > 0) {
                        NSString *name = [tmpArr objectAtIndex: 0];
                        NSString *idContact = [appDelegate._allIDDict objectForKey: phonenumber];
                        if (name != nil && idContact != nil) {
                            fullName = name;
                            avatar = [AppUtils getAvatarOfContact:[idContact intValue]];
                        }
                    }
                }
            }else{
                fullName = pbxContact._name;
                if (pbxContact._avatar != nil){
                    avatar = pbxContact._avatar;
                }
            }
        }else{
            fullName = phonenumber;
        }
        
    }
    return [NSArray arrayWithObjects:fullName, avatar, nil];
}

+ (NSString *)getNameOfContactWithPhoneNumber: (NSString *)phonenumber
{
    NSString *fullName = @"";
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"_sipPhone == %@", phonenumber];
    NSArray *filter = [appDelegate.listContacts filteredArrayUsingPredicate: predicate];
    if (filter.count > 0) {
        ContactObject *aContact = [filter objectAtIndex: 0];
        fullName = aContact._fullName;
    }else{
        //  get name pbx truoc
        NSString *pbxName = [AppUtils getPBXNameWithPhoneNumber: phonenumber];
        if ([pbxName isEqualToString:@""]) {
            NSString *stringValue = [appDelegate._allPhonesDict objectForKey: phonenumber];
            if (![stringValue isEqualToString:@""] && stringValue != nil) {
                NSArray *tmpArr = [stringValue componentsSeparatedByString:@"|"];
                if (tmpArr.count > 0) {
                    NSString *name = [tmpArr objectAtIndex: 0];
                    if (name != nil) {
                        fullName = name;
                    }
                }
            }
        }else{
            fullName = pbxName;
        }
    }
    return fullName;
}

+ (NSString *)getAvatarOfContactWithPhoneNumber: (NSString *)phonenumber
{
    NSString *avatar = @"";
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"_sipPhone == %@", phonenumber];
    NSArray *filter = [appDelegate.listContacts filteredArrayUsingPredicate: predicate];
    if (filter.count > 0) {
        ContactObject *aContact = [filter objectAtIndex: 0];
        avatar = aContact._avatar;
    }else{
        for (int iCount=0; iCount<appDelegate.listContacts.count; iCount++) {
            ContactObject *contact = [appDelegate.listContacts objectAtIndex: iCount];
            predicate = [NSPredicate predicateWithFormat:@"_valueStr = %@", phonenumber];
            filter = [contact._listPhone filteredArrayUsingPredicate: predicate];
            if (filter.count > 0) {
                avatar = contact._avatar;
                break;
            }
        }
    }
    return avatar;
}

+ (NSDictionary *)getProfileInfoOfAccount: (NSString *)account
{
    NSDictionary *rsDict;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT * FROM profile WHERE account = '%@'", account];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        rsDict = [rs resultDictionary];
    }
    [rs close];
    return rsDict;
}

+ (NSString *)getAvatarOfAccount: (NSString *)account
{
    NSString *avatar;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT avatar FROM profile WHERE account = '%@'", account];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        avatar = [rsDict objectForKey:@"avatar"];
    }
    [rs close];
    return avatar;
}

// insert last login cho user
+ (BOOL)insertLastLogoutForUser: (NSString *)account passWord: (NSString *)password andRelogin: (int)relogin {
    [appDelegate._database beginTransaction];
    
    NSString *delSQL = [NSString stringWithFormat:@"DELETE FROM last_logout"];
    BOOL result = [appDelegate._database executeUpdate: delSQL];
    if (result) {
        NSString *newSQL = [NSString stringWithFormat:@"INSERT INTO last_logout(account, password, relogin) VALUES ('%@', '%@', %d)", account, password, relogin];
        result = [appDelegate._database executeUpdate: newSQL];
    }
    if (!result) {
        [appDelegate._database rollback];
    }
    [appDelegate._database commit];
    return result;
}

+ (NSString *)getUserAccountForLastLogin {
    NSString *userId = @"";
    NSString *tSQL = @"SELECT account FROM last_logout LIMIT 0,1";
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        userId = [rsDict objectForKey:@"account"];
    }
    [rs close];
    return userId;
}

//  kiểm tra cloudfoneId có trong blacklist hay ko?
+ (BOOL)checkCloudFoneIDInBlackList: (NSString *)cloudfoneID ofAccount: (NSString *)account {
    BOOL result = false;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT * FROM group_members WHERE id_group = %d AND callnex_id = '%@' AND account = '%@' LIMIT 0,1", 0, cloudfoneID, account];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        result = true;
        break;
    }
    [rs close];
    return result;
}

>>>>>>> parent of b27140b1... Custom switch button
// Get danh sách cuộc gọi với một số
+ (NSMutableArray *)getAllListCallOfMe: (NSString *)account withPhoneNumber: (NSString *)phoneNumber{
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    NSString *dateSQL = @"";
    // Viết câu truy vấn cho get hotline history
    if ([phoneNumber isEqualToString: hotline]) {
        dateSQL = [NSString stringWithFormat:@"SELECT date FROM history WHERE my_sip='%@' AND phone_number = '%@' GROUP BY date ORDER BY _id DESC", account, phoneNumber];
    }else{
        dateSQL = [NSString stringWithFormat:@"SELECT date FROM history WHERE my_sip='%@' AND phone_number LIKE '%%%@%%' GROUP BY date ORDER BY _id DESC", account, phoneNumber];
    }
    
    FMResultSet *rs = [appDelegate._database executeQuery: dateSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        NSString *dateStr = [rsDict objectForKey:@"date"];
        
        CallHistoryObject *aCall = [[CallHistoryObject alloc] init];
        aCall._date = dateStr;
        aCall._rate = -1;
        aCall._duration = -1;
        [result addObject: aCall];
        [result addObjectsFromArray:[self getAllCallOfMe:account withPhone:phoneNumber onDate:dateStr]];
    }
    [rs close];
    return result;
}

+ (NSMutableArray *)getAllCallOfMe: (NSString *)mySip withPhone: (NSString *)phoneNumber onDate: (NSString *)dateStr{
    NSMutableArray *resultArr = [[NSMutableArray alloc] init];
    
    NSString *tSQL = @"";
    // Viết câu truy vấn cho get hotline history
    if ([phoneNumber isEqualToString: hotline]) {
        tSQL = [NSString stringWithFormat:@"SELECT * FROM history WHERE my_sip='%@' AND phone_number = '%@' AND date='%@' ORDER BY _id DESC", mySip, phoneNumber, dateStr];
    }else{
        tSQL = [NSString stringWithFormat:@"SELECT * FROM history WHERE my_sip='%@' AND phone_number LIKE '%%%@%%' AND date='%@' ORDER BY _id DESC", mySip, phoneNumber, dateStr];
    }
    
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        
        NSString *time = [rsDict objectForKey:@"time"];
        NSString *status = [rsDict objectForKey:@"status"];
        int duration = [[rsDict objectForKey:@"duration"] intValue];
        float rate = [[rsDict objectForKey:@"rate"] floatValue];
        NSString *call_direction = [rsDict objectForKey:@"call_direction"];
        long timeInt = [[rsDict objectForKey:@"time_int"] longValue];
        
        CallHistoryObject *aCall = [[CallHistoryObject alloc] init];
        aCall._time = time;
        aCall._status= status;
        aCall._duration = duration;
        aCall._rate = rate;
        aCall._date = @"date";
        aCall._callDirection = call_direction;
        aCall._timeInt = timeInt;
        
        [resultArr addObject: aCall];
    }
    [rs close];
    return resultArr;
}

// Lấy số phone cuối cùng gọi đi
+ (NSString *)getLastCallOfUser {
    NSString *phone = @"";
    NSString *tSQL = [NSString stringWithFormat:@"SELECT phone_number FROM history WHERE my_sip = '%@' AND call_direction = '%@' AND sipURI NOT LIKE '%%%@%%'  ORDER BY _id DESC LIMIT 0,1", USERNAME, outgoing_call, hotline];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        phone = [rsDict objectForKey:@"phone_number"];
        if (phone.length > 3) {
            NSString *headerPrefix = [phone substringToIndex: 3];
            if ([headerPrefix isEqualToString:@"sv-"]) {
                phone = [phone substringFromIndex: 3];
            }else{
                NSRange range = [phone rangeOfString:@",,"];
                if (range.location != NSNotFound) {
                    NSString *tmpStr = [phone substringFromIndex: range.location+range.length];
                    phone = [tmpStr substringToIndex: tmpStr.length-1];
                }
            }
        }
    }
    [rs close];
    return phone;
}

//  Kiểm tra user có nằm trong danh sách tắt thông báo hay không
+ (BOOL)checkUserExistsInMuteNotificationsList: (NSString *)user {
    BOOL result = false;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT mutes FROM conversation WHERE account = '%@' AND user = '%@' LIMIT 0,1", USERNAME, user];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        NSDictionary *rsDict = [rs resultDictionary];
        int mutes = [[rsDict objectForKey:@"mutes"] intValue];
        if (mutes == 0) {
            result = false;
        }else{
            result = true;
        }
    }
    [rs close];
    return result;
}

//  Get call history info with callId
+ (NSDictionary *)getCallInfoWithHistoryCallId: (int)callId {
    NSDictionary *rsDict;
    NSString *tSQL = [NSString stringWithFormat:@"SELECT * FROM history WHERE _id = %d ", callId];
    FMResultSet *rs = [appDelegate._database executeQuery: tSQL];
    while ([rs next]) {
        rsDict = [rs resultDictionary];
    }
    [rs close];
    return rsDict;
}

+ (BOOL)removeHistoryCallsOfUser: (NSString *)user onDate: (NSString *)date ofAccount: (NSString *)account {
    NSString *tSQL = [NSString stringWithFormat:@"DELETE FROM history WHERE my_sip = '%@' AND phone_number = '%@' AND date = '%@'", account, user, date];
    BOOL result = [appDelegate._database executeUpdate: tSQL];
    return result;
}

@end
