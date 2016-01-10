//
//  OrderModel.h
//  DuDu
//
//  Created by i-chou on 12/28/15.
//  Copyright © 2015 i-chou. All rights reserved.
//

#import <Mantle/Mantle.h>

@interface OrderModel : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSNumber *user_id;

@property (nonatomic, copy) NSString *start_lat;
@property (nonatomic, copy) NSString *start_lng;
@property (nonatomic, copy) NSString *star_loc_str;
@property (nonatomic, copy) NSString *dest_lat;
@property (nonatomic, copy) NSString *dest_lng;
@property (nonatomic, copy) NSString *dest_loc_str;
@property (nonatomic, copy) NSNumber *car_style;
@property (nonatomic, copy) NSNumber *startTimeType;
@property (nonatomic, copy) NSString *startTimeStr;

@property (nonatomic, copy) NSNumber *coupon_id;
@property (nonatomic, copy) NSString *coupon_discount;
@property (nonatomic, copy) NSString *coupon_title;

@property (nonatomic, copy) NSString *order_time;
@property (nonatomic, copy) NSNumber *order_id;
@property (nonatomic, copy) NSString *order_initiate_rate;
@property (nonatomic, copy) NSString *order_mileage;
@property (nonatomic, copy) NSString *order_mileage_money;
@property (nonatomic, copy) NSString *order_duration_money;
@property (nonatomic, copy) NSString *order_allMoney;
@property (nonatomic, copy) NSString *order_allTime;
@property (nonatomic, copy) NSNumber *order_status;
@property (nonatomic, copy) NSString *order_status_str;
@property (nonatomic, copy) NSNumber *order_payStatus;
@property (nonatomic, copy) NSString *order_payStatus_str;

@property (nonatomic, copy) NSNumber *driver_status;
@property (nonatomic, copy) NSString *driver_status_str;
@property (nonatomic, copy) NSNumber *isbook;
@property (nonatomic, copy) NSNumber *relevance_id;
@property (nonatomic, copy) NSNumber *evaluate_level;

@property (nonatomic, copy) NSNumber *car_position_id;
@property (nonatomic, copy) NSString *car_color;
@property (nonatomic, copy) NSString *car_plate_number;
@property (nonatomic, copy) NSString *driver_nickname;
@property (nonatomic, copy) NSNumber *driver_telephone;
@property (nonatomic, copy) NSString *driver_photo;
@property (nonatomic, copy) NSString *car_brand;
@property (nonatomic, copy) NSArray  *location;

@end
