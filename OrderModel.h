//
//  OrderModel.h
//  DuDu
//
//  Created by i-chou on 12/28/15.
//  Copyright © 2015 i-chou. All rights reserved.
//

#import <Mantle/Mantle.h>

@interface OrderModel : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong) NSNumber *user_id;
@property (nonatomic, strong) NSString *start_lat;
@property (nonatomic, strong) NSString *start_lng;
@property (nonatomic, strong) NSString *start_loc_str;
@property (nonatomic, strong) NSString *dest_lat;
@property (nonatomic, strong) NSString *dest_lng;
@property (nonatomic, strong) NSString *dest_loc_str;
@property (nonatomic, strong) NSString *car_style;
@property (nonatomic, strong) NSString *startTimeType;
@property (nonatomic, strong) NSString *startTimeStr;
@property (nonatomic, strong) NSString *order_time;
@property (nonatomic, strong) NSNumber *order_id;

@property (nonatomic, strong) NSString *order_initiate_rate;
@property (nonatomic, strong) NSString *order_mileage;
@property (nonatomic, strong) NSString *order_mileage_money;
@property (nonatomic, strong) NSString *order_duration_money;
@property (nonatomic, strong) NSString *order_allMoney;
@property (nonatomic, strong) NSString *order_allTime;

@property (nonatomic, strong) NSNumber *order_status;
@property (nonatomic, strong) NSNumber *driver_status;
@property (nonatomic, strong) NSNumber *order_payStatus;
@property (nonatomic, strong) NSNumber *coupon_id;
@property (nonatomic, strong) NSString *coupon_title;

@property (nonatomic, assign) BOOL     isbook;

@end
