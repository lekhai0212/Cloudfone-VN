//
//  ContactUtils.h
//  linphone
//
//  Created by lam quang quan on 11/2/18.
//

#import <Foundation/Foundation.h>

@interface ContactUtils : NSObject

+ (PhoneObject *)getContactPhoneObjectWithNumber: (NSString *)number;
+ (NSString *)getContactNameWithNumber: (NSString *)number;
+ (NSAttributedString *)getSearchValueFromResultForNewSearchMethod: (NSArray *)searchs;

@end
