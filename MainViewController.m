//
//  MainViewController.m
//  DuDu
//
//  Created by i-chou on 11/4/15.
//  Copyright © 2015 i-chou. All rights reserved.
//

#import "MainViewController.h"
#import "CouponModel.h"
#import "OrderVC.h"
#import "LoginVC.h"
#import "CouponStore.h"
#import <objc/runtime.h>
#import "RouteDetailVC.h"
#import "hitchhikeVC.h"
#import "SIAlertView.h"

#define PADDING 10
#define bottomToolBar_Height  88

@interface MainViewController ()

@end

@implementation MainViewController
{
    BottomToolBar   *_bottomToolBar;
    TimePicker      *_timePicker;
    MenuTableViewController *_menuVC;
    OrderVC                 *_orderVC;
    
    NSString        *_currentCity;
    UIButton        *_locationBtn;
    QPointAnnotation   *_fromPointAnnotation;
    QPointAnnotation   *_toPointAnnotation;
    BOOL            _isFirstAppear;
    BOOL            _isAppointment; //是否是预约
    NSTimeInterval  _startTimeStr;
    BOOL            _isUpdated;
    QMSRoutePlan    *_currentRoutPlan;
    CouponModel     *_currentCoupon;
    float           _currentMoney; //优惠之前的价格
    float           _chargeMoney; //结算用的价格
    
    UIView          *_adView;
    UIImageView     *_adImageView;
    BOOL            _isAdShowing;
    BOOL            _isCheckedCoupon;
    BOOL            _isUnuseCoupon;
    
    SIAlertView     *_alertView;
}

+ (instancetype)sharedMainViewController
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedMainViewController = nil;
    dispatch_once(&pred, ^{
        _sharedMainViewController = [[self alloc] init];
    });
    return _sharedMainViewController;
}

- (id)init
{
    self = [super init];
    if (self) {
        _menuVC = [[MenuTableViewController alloc] init];
        _menuVC.title = @"个人中心";
        
        _orderVC = [[OrderVC alloc] init];
        _orderVC.title = @"正在为你预约嘟嘟快车";
        _fromLocation = [[QUserLocation alloc] init];
        _toLocation = [[QUserLocation alloc] init];
        
        self.orderStore = [[OrderStore alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _isFirstAppear = YES;
    
    [self setupLeftMenuButton];
    
    [QMapServices sharedServices].apiKey = QMAP_KEY;
    [QMSSearchServices sharedServices].apiKey = QMAP_KEY;
    
    self.search = [[QMSSearcher alloc] initWithDelegate:self];
    
    self.mapView = [[QMapView alloc] initWithFrame:ccr(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    self.mapView.delegate = self;
    [self.view addSubview:self.mapView];
    
    self.mapView.userTrackingMode = QUserTrackingModeFollow;
    
    self.topToolBar = [[TopToolBar alloc] initWithFrame:ccr(0,
                                                            NAV_BAR_HEIGHT_IOS7,
                                                            SCREEN_WIDTH,
                                                            50)
                                              carStyles:self.carStyles];
    self.topToolBar.delegate = self;
    [self.view addSubview:self.topToolBar];
    
    _bottomToolBar = [[BottomToolBar alloc] initWithFrame:ccr(PADDING,
                                                              SCREEN_HEIGHT-bottomToolBar_Height-PADDING,
                                                              SCREEN_WIDTH-PADDING*2,
                                                              bottomToolBar_Height)];
    _bottomToolBar.delegate = self;
    [self.view addSubview:_bottomToolBar];
    
    _timePicker = [[TimePicker alloc] initWithFrame:ccr(0, SCREEN_HEIGHT, SCREEN_WIDTH, 264)];
    _timePicker.delegate = self;
    [self.view addSubview:_timePicker];
    
    _locationBtn = [UIButton buttonWithImageName:@"icon_my_location_48px"
                                     hlImageName:@"icon_my_location_48px"
                                      onTapBlock:^(UIButton *btn) {
                                          [self locateMapView];
                                      }];
    _locationBtn.frame = ccr(PADDING, CGRectGetMaxY(self.topToolBar.frame)+PADDING, 30, 30);
    [self.view addSubview:_locationBtn];
    
    [self.navigationController.view addSubview:[self adView]];
    [self startLocation];
    [self getAd];
    
}

- (void)clearData
{
    _isAppointment = NO;
    NSDate *now = [NSDate date];
    _startTimeStr = [now timeIntervalSince1970];
    
    _bottomToolBar.startTimeLabel.text = @"提前预约，出行方便";
    _bottomToolBar.fromAddressLabel.text = @"从哪儿出发";
    _bottomToolBar.fromAddressLabel.textColor = COLORRGB(0xf39a00);
    _bottomToolBar.toAddressLabel.text = @"你要去哪儿";
    _bottomToolBar.toAddressLabel.textColor = COLORRGB(0xf39a00);
    [_bottomToolBar showChargeView:NO];
    [_bottomToolBar showTimeLabel:NO];
    _isUpdated = NO;
    _currentCoupon = nil;
    [self clearMapView];
    [self startLocation];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!_isAdShowing) {
        [self getOrderList];
    }
    if (_currentCoupon) {
        [self guessChargeWithCoupon:_currentCoupon routPlan:_currentRoutPlan carStyle:_currentCar];
    } else {
        if (!_isUnuseCoupon) {
            [self getCouponInfo];
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self showAdView:NO];
    _isFirstAppear = NO;
}

- (void)clearMapView
{
    _currentRoutPlan = nil;
    _fromPointAnnotation = nil;
    _toPointAnnotation = nil;
//    self.mapView.showsUserLocation = NO;
    [self.mapView removeAnnotations:self.mapView.annotations];
    [self.mapView removeOverlays:self.mapView.overlays];
}

- (void)getAd
{
    _isAdShowing = YES;
    [[DuDuAPIClient sharedClient] GET:CHECK_VERSION parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        //获取广告信息
        adModel *adInfo =
        [MTLJSONAdapter modelOfClass:[adModel class]
                  fromJSONDictionary:[DuDuAPIClient parseJSONFrom:responseObject][@"ad"]
                               error:nil];
        self.adInfo = adInfo;
        if (self.adInfo && [self.adInfo.advertisement_status intValue]==1) {
            NSString *src = self.adInfo.advertisement_url;
            if (![Utils isValidURL:src]) {
                src = ADD(@"http://www.kupaocar.cn", src);
            }
            [_adImageView setImageWithURL:URL(src)];
            [self showAdView:YES];
        } else {
            [self showAdView:NO];
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        _isAdShowing = NO;
    }];
}

- (void)showAdView:(BOOL)show
{
    [UIView animateWithDuration:0.3 animations:^{
        _adView.alpha = show;
    } completion:^(BOOL finished) {
        _isAdShowing = show;
        if (!show & _isFirstAppear) { //第一次进入主页面并且没有展示的时候才显示广告
            [self getOrderList];
//            _isFirstAppear = NO;
        }
    }];
}

- (UIView *)adView
{
    if (!_adView) {
        _adView = [[UIView alloc] initWithFrame:ccr(0, 0, SCREEN_WIDTH,SCREEN_HEIGHT)];
        _adView.backgroundColor = COLORRGBA(0x000000, 0.2);
        CGRect adFrame;
        if (IS_BETTER_THAN_IPHONE_4S) {
            adFrame = ccr((SCREEN_WIDTH-300+10)/2, (SCREEN_HEIGHT-400+10)/2, 300-10, 400-10);
        } else {
            adFrame = ccr((SCREEN_WIDTH-240+10)/2, (SCREEN_HEIGHT-320+10)/2, 240-10, 320-10);
        }
        
        _adImageView = [[UIImageView alloc] initWithFrame:adFrame];
        _adImageView.backgroundColor = COLORRGB(0xffffff);
        _adImageView.layer.borderColor = COLORRGB(0xdedede).CGColor;
        _adImageView.layer.borderWidth = 0.5f;
        _adImageView.layer.cornerRadius = 3.0f;
        _adImageView.layer.masksToBounds = YES;
        [_adView addSubview:_adImageView];
        UIButton *closeBtn = [UIButton buttonWithImageName:@"close_btn" hlImageName:@"close_btn_hl" onTapBlock:^(UIButton *btn) {
            [self showAdView:NO];
        }];
        closeBtn.frame = ccr(CGRectGetMaxX(_adImageView.frame)-20, _adImageView.y-10, 30, 30);
        [_adView addSubview:closeBtn];
    }
    return _adView;
}

- (void)getOrderList
{
    [[DuDuAPIClient sharedClient] GET:USER_ORDER_INFO parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        
        NSDictionary *dic = [DuDuAPIClient parseJSONFrom:responseObject][@"info"];
        NSArray *ing = [MTLJSONAdapter modelsOfClass:[OrderModel class]
                                       fromJSONArray:dic[@"ing"]
                                               error:nil];
        
        NSArray *history = [MTLJSONAdapter modelsOfClass:[OrderModel class]
                                       fromJSONArray:dic[@"history"]
                                               error:nil];
        self.orderStore.ing = [ing mutableCopy];
        self.orderStore.history = [history mutableCopy];
        
        //第一次进入画面并且没有未完成订单时进行用户定位
        if (!self.orderStore.ing.count) {
            if (_isFirstAppear) {
                [self startLocation];
                _isFirstAppear = NO;
            }
        } else {
            OrderModel *orderInfo = _orderStore.ing[0];
            
            if ([orderInfo.order_status intValue] == OrderStatusWatingForDriver) { //等待派单
                OrderVC *orderVC = [[OrderVC alloc] init];
                orderVC.orderInfo = orderInfo;
                orderVC.isModal = YES;
                orderVC.canTimerShow = NO;
                orderVC.resultStatus = [dic[@"err"] intValue];
                orderVC.title = @"当前订单";
                orderVC.orderStatusInfo = @"嘟嘟正在为您分派司机，请稍候...";
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:orderVC];
                [nav.navigationBar setTranslucent:NO];
                [nav.navigationBar setBarTintColor:COLORRGB(0xf39a00)];
                [nav.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor],NSForegroundColorAttributeName,HSFONT(16),NSFontAttributeName,nil]];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
            } else if ([orderInfo.order_status intValue] == OrderStatusDriverCancel) { //司机取消（理论上不会返回这个状态的订单信息）
                [ZBCToast showMessage:@"司机取消订单"];
                RouteDetailVC *detailVC = [[RouteDetailVC alloc] init];
                detailVC.title = @"订单详情";
                detailVC.orderInfo = orderInfo;
                detailVC.isHistory = NO;
                detailVC.isForCharge = NO;
                detailVC.isModal = YES;
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:detailVC];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
            } else if ([orderInfo.order_status intValue] == OrderStatusTravelStart) { //开始乘车
                OrderVC *orderVC = [[OrderVC alloc] init];
                orderVC.orderInfo = orderInfo;
                orderVC.isModal = YES;
                orderVC.canTimerShow = NO;
                orderVC.resultStatus = [dic[@"err"] intValue];
                orderVC.title = @"当前订单";
                orderVC.orderStatusInfo = @"行程中，嘟嘟正在为您服务";
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:orderVC];
                [nav.navigationBar setTranslucent:NO];
                [nav.navigationBar setBarTintColor:COLORRGB(0xf39a00)];
                [nav.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor],NSForegroundColorAttributeName,HSFONT(16),NSFontAttributeName,nil]];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
                [self clearData];
            } else if ([orderInfo.order_status intValue] == OrderStatusWatingForPay) { //等待付款
                [ZBCToast showMessage:@"请尽快付款"];
                RouteDetailVC *detailVC = [[RouteDetailVC alloc] init];
                detailVC.title = @"订单详情";
                detailVC.orderInfo = orderInfo;
                detailVC.isHistory = NO;
                detailVC.isForCharge = YES;
                detailVC.isModal = YES;
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:detailVC];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
                [self clearData];
            } else if ([orderInfo.order_status intValue] == OrderStatusDriverIsComing) { //司机前往
                OrderVC *orderVC = [[OrderVC alloc] init];
                orderVC.orderInfo = orderInfo;
                orderVC.isModal = YES;
                orderVC.canTimerShow = NO;
                orderVC.resultStatus = [dic[@"err"] intValue];
                orderVC.title = @"当前订单";
                orderVC.orderStatusInfo = @"司机正在前往，请耐心等待";
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:orderVC];
                [nav.navigationBar setTranslucent:NO];
                [nav.navigationBar setBarTintColor:COLORRGB(0xf39a00)];
                [nav.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor],NSForegroundColorAttributeName,HSFONT(16),NSFontAttributeName,nil]];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
            } else if ([orderInfo.order_status intValue] == OrderStatusComleted) { //订单完成
                //下单接口中不该返回完成状态的订单信息，不做处理
                return;
            }
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        
    }];
}


#pragma mark - 开始定位当前位置
- (void)startLocation
{
    self.mapView.showsUserLocation = YES;
    [self.mapView setZoomLevel:16.1 animated:YES];
}

- (void)locateMapView
{
//    [self clearData];
    [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:YES];
}

-(void)setupLeftMenuButton
{
    UIButton *leftBtn = [UIButton buttonWithImageName:@"account" hlImageName:@"account_pressed"onTapBlock:^(UIButton *btn) {
        if ([self checkHaveLogin]) {
            [self.navigationController pushViewController:_menuVC animated:YES];
        } else {
            LoginVC *loginVC = [[LoginVC alloc] init];
            loginVC.delegate = self;
            loginVC.title = @"验证手机";
            ZBCNavVC *navVC = [[ZBCNavVC alloc] initWithRootViewController:loginVC];
            [self presentViewController:navVC animated:YES completion:nil];
        }
    }];
    leftBtn.frame = ccr(0, 0, 30, 30);
    UIBarButtonItem *BarItem = [[UIBarButtonItem alloc] initWithCustomView:leftBtn];
    [self.navigationItem setLeftBarButtonItem:BarItem animated:YES];
}

- (void)showTimePicker:(BOOL)show
{
    if (show) {
        [UIView animateWithDuration:0.3 animations:^{
            _timePicker.y = SCREEN_HEIGHT - _timePicker.height;
        }];
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            _timePicker.y = SCREEN_HEIGHT;
        }];
    }
}

- (void)showFromAddressPicker
{
    GeoAndSuggestionViewController *searchVC = [[GeoAndSuggestionViewController alloc] init];
    searchVC.delegate = self;
    searchVC.historyOrders = self.orderStore.history;
    searchVC.title = @"出发地";
    searchVC.isFrom = YES;
    searchVC.currentCity = _currentCity;
    [self.navigationController pushViewController:searchVC animated:YES];
}

- (void)showToAddressPicker
{
    GeoAndSuggestionViewController *searchVC = [[GeoAndSuggestionViewController alloc] init];
    searchVC.delegate = self;
    searchVC.historyOrders = self.orderStore.history;
    searchVC.title = @"目的地";
    searchVC.isFrom = NO;
    searchVC.currentCity = _currentCity;
    [self.navigationController pushViewController:searchVC animated:YES];
}

- (void)showCouponPicker
{
    CouponVC *couponVC =[[CouponVC alloc] init];
    couponVC.title = @"选择优惠券";
    couponVC.showUnuseHeader = YES;
    couponVC.delegate = self;
    couponVC.money = _currentMoney;
    couponVC.carStyle = _currentCar;
    [self.navigationController pushViewController:couponVC animated:YES];
}

#pragma mark - 发送订单
/*
- (void)sentOrder:(OrderModel *)orderInfo
{
    //TODO:让后台把接口返回同一字段类型统一
    OrderModel *order = [MTLJSONAdapter modelOfClass:[OrderModel class]
                                  fromJSONDictionary:[DuDuAPIClient parseJSONFrom:[Utils testDicFrom:@"orderInfo"][@"info"]]
                                               error:nil];
 
    [OrderVC sharedOrderVC].orderInfo = order;
    [self.navigationController pushViewController:[OrderVC sharedOrderVC] animated:YES];
}
*/

- (void)sentOrder:(OrderModel *)order
{
    NSString *url = ADD_ORDER(order.start_lat,
                              order.start_lng,
                              order.star_loc_str,
                              order.dest_lat,
                              order.dest_lng,
                              order.dest_loc_str,
                              order.car_style,
                              order.startTimeType,
                              order.startTimeStr,
                              _isUnuseCoupon?nil:_currentCoupon.coupon_id,
                              0,
                              _chargeMoney);
    
    if (![UICKeyChainStore stringForKey:KEY_STORE_ACCESS_TOKEN service:KEY_STORE_SERVICE]) {
        [ZBCToast showMessage:@"请先登录"];
        return;
    }
    [[DuDuAPIClient sharedClient] GET:url parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        
        NSDictionary *dic = [DuDuAPIClient parseJSONFrom:responseObject];
        if (dic) {
            if ([dic[@"err"] intValue] == OrderResultSuccess ||
                [dic[@"err"] intValue] == OrderResultHaveOtherCar) { //正常情况，等待司机接单 || 有其他车辆推荐
                OrderModel *orderInfo = [[OrderModel alloc] init];
                orderInfo.car_style = dic[@"info"][@"car_style"];
                orderInfo.coupon_id = dic[@"info"][@"coupon_id"];
                orderInfo.dest_lat = dic[@"info"][@"dest_lat"];
                orderInfo.dest_lng = dic[@"info"][@"dest_lng"];
                orderInfo.dest_loc_str = dic[@"info"][@"dest_loc_str"];
                orderInfo.order_id = dic[@"info"][@"order_id"];
                orderInfo.order_time = dic[@"info"][@"order_time"];
                orderInfo.star_loc_str = dic[@"info"][@"star_loc_str"];
                orderInfo.startTimeStr = dic[@"info"][@"startTimeStr"];
                orderInfo.startTimeType = dic[@"info"][@"startTimeType"];
                orderInfo.start_lat = dic[@"info"][@"start_lat"];
                orderInfo.start_lng = dic[@"info"][@"start_lng"];
                orderInfo.user_id = dic[@"info"][@"user_id"];
                orderInfo.startTimeType = order.startTimeType;
                
                OrderVC *orderVC = [[OrderVC alloc] init];
                
                if ([dic[@"err"] intValue] == OrderResultHaveOtherCar) {
                    CarStore *carStore = [[CarStore alloc] init];
                    carStore.cars = [MTLJSONAdapter modelOfClass:[CarModel class]
                                              fromJSONDictionary:dic[@"car_style"]
                                                           error:nil];
                    orderVC.carStore = carStore;
                }
                orderVC.orderInfo = orderInfo;
                orderVC.resultStatus = [dic[@"err"] intValue];
                orderVC.title = @"当前订单";
                orderVC.canTimerShow = YES;
//                orderVC.orderStatusInfo = dic[@"order_info"];
                orderVC.orderStatusInfo = @"嘟嘟正在为您分派司机，请稍候...";
//                if ([orderInfo.startTimeType intValue]) {
//                    orderVC.orderStatusInfo = @"嘟嘟正在为您分派司机，请稍候...";
//                } else {
//                    orderVC.orderStatusInfo = @"嘟嘟正在为您分派司机，请稍候...";
//                }
                
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:orderVC];
                [nav.navigationBar setTranslucent:NO];
                [nav.navigationBar setBarTintColor:COLORRGB(0xf39a00)];
                [nav.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor],NSForegroundColorAttributeName,HSFONT(16),NSFontAttributeName,nil]];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
                
            } else if([dic[@"err"] intValue] == OrderResultNotCompleted){ //订单未完成，理论不会有这个分支，因为只要有未完成订单就直接跳到详情页
                return;
            } else if([dic[@"err"] intValue] == OrderResultCouponCantUse) { //优惠券不可用
                [ZBCToast showMessage:@"优惠券不可用"];
                return;
            } else if([dic[@"err"] intValue] == OrderResultNoCarUse){ //没有可用车辆
                OrderVC *orderVC = [[OrderVC alloc] init];
                orderVC.orderInfo = order;
                orderVC.isModal = YES;
                orderVC.resultStatus = [dic[@"err"] intValue];
                orderVC.title = @"当前订单";
                orderVC.canTimerShow = YES;
                orderVC.orderStatusInfo = @"嘟嘟正在为您分派司机，请稍候...";
                ZBCNavVC *nav = [[ZBCNavVC alloc] initWithRootViewController:orderVC];
                [nav.navigationBar setTranslucent:NO];
                [nav.navigationBar setBarTintColor:COLORRGB(0xf39a00)];
                [nav.navigationBar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIColor whiteColor],NSForegroundColorAttributeName,HSFONT(16),NSFontAttributeName,nil]];
                [self.navigationController presentViewController:nav animated:YES completion:nil];
            } else {
                
            }
        }
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {

    }];
}


#pragma mark - 获取优惠信息

//TODO:remove test
/*
- (void)getCouponInfo
{
    NSArray *arr = [DuDuAPIClient parseJSONFrom:[Utils testDicFrom:@"couponInfo"]][@"info"];
    CouponStore *coupons = [[CouponStore alloc] init];
    coupons.info = [MTLJSONAdapter modelsOfClass:[CouponModel class]
                                   fromJSONArray:arr
                                           error:nil];
    [MenuTableViewController sharedMenuTableViewController].coupons = coupons;
    
    CouponModel *coupon = coupons.info.count?coupons.info[0]:nil;
    [self guessChargeWithCoupon:coupon routPlan:_currentRoutPlan carStyle:_currentCar];
}
*/

- (void)getCouponInfo
{
    [[DuDuAPIClient sharedClient] GET:USER_COUPON_INFO parameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        
        NSDictionary *dic = [DuDuAPIClient parseJSONFrom:responseObject];
        NSArray *arr = [MTLJSONAdapter modelsOfClass:[CouponModel class]
                                       fromJSONArray:dic[@"info"]
                                               error:nil];
        [CouponStore sharedCouponStore].info = arr;
                                
        [MenuTableViewController sharedMenuTableViewController].coupons = [CouponStore sharedCouponStore];
        
        _currentCoupon = [CouponStore sharedCouponStore].useableCoupons.count?[CouponStore sharedCouponStore].useableCoupons[0]:nil;
        [self guessChargeWithCoupon:_currentCoupon routPlan:_currentRoutPlan carStyle:_currentCar];
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        _bottomToolBar.couponLabel.text = @"暂无优惠";
    }];
}

#pragma mark - 估算费用
- (void)guessChargeWithCoupon:(CouponModel *)coupon routPlan:(QMSRoutePlan *)plan carStyle:(CarModel *)car
{
    float distance = plan.distance/1000; //距离
    if ([CouponStore sharedCouponStore].shareInfo.distance_length.length) {
        distance = distance * [[CouponStore sharedCouponStore].shareInfo.distance_length floatValue];//距离*距离系数(客户要求)
    }
    
    float duration = plan.duration; //时长
    float per_kilometer_money = car.per_kilometer_money; //起步里程每公里价格
    float per_max_kilometer = car.per_max_kilometer; //起步公里数
    float per_max_kilometer_money = car.per_max_kilometer_money; //超长每公里价格
    float wait_time_money = car.wait_time_money; //等时费
    float start_money = car.start_money; //起步价
    
    float charge = 0;
    
    //实际价格计算
    if (distance <= per_max_kilometer) {
        charge = distance*per_kilometer_money
        + duration*wait_time_money;
    } else {
        charge = per_max_kilometer*per_kilometer_money
        + (distance - per_max_kilometer)*per_max_kilometer_money
        + duration*wait_time_money;
    }
    
    //夜间服务费
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:_startTimeStr];
    
    if ([Utils checkNightService:date] && _currentCar.night_service_times.length) {
        charge = charge * [_currentCar.night_service_times floatValue];
        start_money = start_money * [_currentCar.night_service_times floatValue];
    }
    _currentMoney = charge;
    //给出最优惠券
    if (!_isUnuseCoupon && !_isCheckedCoupon) {
        coupon = [[CouponStore sharedCouponStore] cheapestCoupon:charge carStyle:_currentCar];
        _currentCoupon = coupon;
    }
    
    //根据不同优惠类型计算折扣价
    if (coupon && [coupon.coupon_discount floatValue] < 1) {
        charge = charge * [coupon.coupon_discount floatValue];
    } else {
        charge = charge - [coupon.coupon_discount floatValue];
    }
    
    //保证费用不少于起步价（首单不受此约束）
    if (charge < start_money && ![[CouponStore sharedCouponStore].shareInfo.user_isFreeTaxi intValue]) {
        charge = start_money;
    }

    //保证费用为非负数
    if (charge < 0) {
        charge = 0;
    }
    _chargeMoney = charge;
    [_bottomToolBar updateCharge:[NSString stringWithFormat:@"%.1f",charge] coupon:coupon];
}

#pragma mark - 发送打车订单
- (void)didSubmited
{
    
//    if (![_currentCity isEqualToString:@"大连市"]) {
//        if (!_alertView) {
//            NSString *message  =[NSString stringWithFormat:@"\n很抱歉，不能为您提供服务，暂时只支持大连地区。期待嘟嘟将来为您服务。\n"];
//            _alertView = [[SIAlertView alloc] initWithTitle:@"" andMessage:message];
//            _alertView.messageFont = HSFONT(14);
//            _alertView.buttonColor = COLORRGB(0xf39a00);
//            _alertView.buttonFont = HSFONT(15);
//            _alertView.cancelButtonColor = COLORRGB(0xf39a00);
//            _alertView.didShowHandler = ^(SIAlertView *alertView) {
//            };
//            _alertView.didDismissHandler = ^(SIAlertView *alertView) {
//                alertView = nil;
//            };
//            _alertView.transitionStyle = SIAlertViewTransitionStyleBounce;
//            
//            [_alertView addButtonWithTitle:@"确定"
//                                          type:SIAlertViewButtonTypeCancel
//                                       handler:^(SIAlertView *alert) {
//                                           [alert dismissAnimated:YES];
//                                       }];
//        }
//        [_alertView show];
//        return;
//    }
    OrderModel *orderInfo = [[OrderModel alloc] init];
    orderInfo.user_id = [NSNumber numberWithInt:[[UICKeyChainStore stringForKey:KEY_STORE_USERID service:KEY_STORE_SERVICE] intValue]];
    
    orderInfo.start_lat = [NSString stringWithFormat:@"%.6f",_fromPointAnnotation.coordinate.latitude];
    orderInfo.start_lng = [NSString stringWithFormat:@"%.6f",_fromPointAnnotation.coordinate.longitude];
    orderInfo.dest_lat = [NSString stringWithFormat:@"%.6f",_toPointAnnotation.coordinate.latitude];
    orderInfo.dest_lng = [NSString stringWithFormat:@"%.6f",_toPointAnnotation.coordinate.longitude];
    orderInfo.star_loc_str = _bottomToolBar.fromAddressLabel.text;
    orderInfo.dest_loc_str = _bottomToolBar.toAddressLabel.text;
    orderInfo.car_style = _currentCar.car_style_id;
    if (!_isAppointment) { //不是预约单，取现在时间
        NSDate *now = [NSDate date];
        _startTimeStr = [now timeIntervalSince1970];
    }
    orderInfo.startTimeStr = [NSString stringWithFormat:@"%d",(int)_startTimeStr];
    orderInfo.startTimeType = [NSNumber numberWithInt:_isAppointment];
    
    [self sentOrder:orderInfo];
}

#pragma mark - GeoAndSuggestionViewControllerDelegate

- (void)addressPicker:(GeoAndSuggestionViewController *)vc fromAddress:(QMSSuggestionPoiData *)fromLoc toAddress:(QMSSuggestionPoiData *)toLoc
{
    _currentCity = vc.currentCity;
    _isCheckedCoupon = NO;
    if (fromLoc) {
        NSLog(@"fromLoc:%f,%f",fromLoc.location.latitude,fromLoc.location.longitude);
        [_fromLocation setCoordinate:fromLoc.location];
        [_fromLocation setTitle:fromLoc.title];
        
        _bottomToolBar.fromAddressLabel.text = fromLoc.title;
        _bottomToolBar.fromAddressLabel.textColor = COLORRGB(0x63666b);
        [self setupAnnotation:YES];
    }
    if (toLoc){
        [_toLocation setCoordinate:toLoc.location];
        [_toLocation setTitle:toLoc.title];
        NSLog(@"toLoc:%f,%f,",toLoc.location.latitude,toLoc.location.longitude);
        
        _bottomToolBar.toAddressLabel.text = toLoc.title;
        _bottomToolBar.toAddressLabel.textColor = COLORRGB(0x63666b);
        [_bottomToolBar showChargeView:YES];
        
        [self setupAnnotation:NO];
        if (_currentCoupon) {
            [self guessChargeWithCoupon:_currentCoupon routPlan:_currentRoutPlan carStyle:_currentCar];
        } else {
            [self getCouponInfo];
        }
    }
}


#pragma mark - LoginVCDelegate
- (void)loginSucceed:(UserModel *)userInfo
{
    [MenuTableViewController sharedMenuTableViewController].userInfo = userInfo;
    [MenuTableViewController sharedMenuTableViewController].isUserChanged = YES;
    [self.navigationController pushViewController:[MenuTableViewController sharedMenuTableViewController] animated:YES];
    
}

#pragma mark - TopToolBarDelegate

- (void)topToolBar:(TopToolBar *)topToolBar didCarButonTapped:(int)index
{
    CarModel *car = self.carStyles[index];
    if ([car.car_style_name isEqualToString:@"顺风车"] ) {
        HitchhikeVC *hitchhikeVC = [[HitchhikeVC alloc] init];
        hitchhikeVC.title = @"发布顺风车订单";
        hitchhikeVC.fromLocationStr = _bottomToolBar.fromAddressLabel
        .text;
        hitchhikeVC.fromLocation = _fromLocation;
        hitchhikeVC.currentCity = _currentCity;
        hitchhikeVC.currentCar = car;
        hitchhikeVC.orderStore = self.orderStore;
        [self.navigationController pushViewController:hitchhikeVC animated:YES];
        [_topToolBar updateCarStylesWith:self.carStyles];
    } else {
        _currentCar = self.carStyles[index];
        [self guessChargeWithCoupon:_currentCoupon
                           routPlan:_currentRoutPlan
                           carStyle:_currentCar];
    }
}

#pragma mark - BottomToolBarDelegate

- (void)bottomToolBar:(BottomToolBar *)toolBar didTapped:(UILabel *)label
{
    if (label == toolBar.startTimeLabel) {
        [self showTimePicker:YES];
    } else if (label == toolBar.fromAddressLabel) {
//        self.mapView.showsUserLocation = NO;
        [self showFromAddressPicker];
    } else if (label == toolBar.toAddressLabel) {
        [self showToAddressPicker];
    } else if (label == toolBar.couponLabel){
        [self showCouponPicker];
    } else {
        //do nothing
    }
}

#pragma mark - TimePickerDelegate

- (void)timePickerView:(TimePicker *)pickerView didSelectTime:(NSInteger)timeStamp isRightNow:(BOOL)isRightNow
{
    _isAppointment = !isRightNow;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeStamp];
    NSString *day;
    if ([date isToday]) {
        day = [date displayWithFormat:@"今天 HH:mm"];//@"今天  HH:mm";
    } else if ([date isTomorrow]) {
        day = [date displayWithFormat:@"明天 HH:mm"];//@"明天  HH:mm";
    } else if ([date isEqualToDateIgnoringTime:[NSDate dateWithDaysFromNow:2]]){
        day = [date displayWithFormat:@"后天 HH:mm"];//@"后天  HH:mm";
    } else {
        day = [date displayWithFormat:@"M月d日  HH:mm"];
    }
    _bottomToolBar.startTimeLabel.text = day;//[date displayWithFormat:@"d号H点mm分"];
    _startTimeStr = timeStamp;
    [self showTimePicker:NO];
}

- (void)timePickerViewDidCancel
{
    [self showTimePicker:NO];
}

#pragma mark - CouponVCDelegate

- (void)couponVC:(CouponVC *)vc didSelectCouponIndex:(int)index
{
    _isCheckedCoupon = YES;
    _isUnuseCoupon = NO;
    _currentCoupon = [CouponStore sharedCouponStore].useableCoupons.count?[CouponStore sharedCouponStore].useableCoupons[index]:nil;
    [self guessChargeWithCoupon:_currentCoupon routPlan:_currentRoutPlan carStyle:_currentCar];
}

- (void)didSelectUnuseCoupon
{
    _currentCoupon = nil;
    _isCheckedCoupon = YES;
    _isUnuseCoupon = YES;
    [self guessChargeWithCoupon:_currentCoupon routPlan:_currentRoutPlan carStyle:_currentCar];
}

#pragma mark - ------------- MapView 相关代码 -------------

#pragma mark - 地图打点完成 delegate

- (void)mapView:(QMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
    QAnnotationView *view = views[0];
    [self.mapView selectAnnotation:view.annotation animated:YES];
}

#pragma mark - 自定义打头阵样式

- (QAnnotationView *)mapView:(QMapView *)mapView viewForAnnotation:(id<QAnnotation>)annotation
{
    static NSString *reuseId = @"REUSE_ID";
    QPinAnnotationView *annotationView = (QPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:reuseId];
    
    if (nil == annotationView) {
        annotationView = [[QPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:reuseId];
    }
    
    annotationView.canShowCallout   = YES;
    UILabel *title = [[UILabel alloc] initWithFrame:ccr(0,0,50, 20)];
    title.font = HSFONT(15);
    title.textColor = COLORRGB(0x63666b);
    title.textAlignment = NSTextAlignmentCenter;
    
    annotationView.rightCalloutAccessoryView = title;

    if (annotation == _fromPointAnnotation) {
        annotationView.pinColor = QPinAnnotationColorGreen;
        title.text = @"起点";
    } else if (annotation == _toPointAnnotation) {
        annotationView.pinColor = QPinAnnotationColorRed;
        title.text = @"终点";
    } else {
        return nil;
    }
    
    return annotationView;
}

#pragma mark - 地图开始定位 delegate

- (void)mapViewWillStartLocatingUser:(QMapView *)mapView
{
    NSLog(@"开始定位");
    _bottomToolBar.fromAddressLabel.text = @"定位中...";
}

#pragma mark - 地图停止定位 delegate

- (void)mapViewDidStopLocatingUser:(QMapView *)mapView
{
    NSLog(@"停止定位");
}

#pragma mark - 地图更新定位 delegate

- (void)mapView:(QMapView *)mapView didUpdateUserLocation:(QUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
    if (updatingLocation && !_isUpdated) {
        _fromLocation = userLocation;
        QMSReverseGeoCodeSearchOption *regeocoder = [[QMSReverseGeoCodeSearchOption alloc] init];
        [regeocoder setLocation:[NSString stringWithFormat:@"%f,%f",userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude]];
        [self.mapView setCenterCoordinate:self.mapView.userLocation.coordinate animated:YES];
        //返回坐标点附近poi列表
        [regeocoder setGet_poi:NO];
        //设置坐标所属坐标系，以返回正确地址，默认为腾讯所用坐标系
        [regeocoder setCoord_type:QMSReverseGeoCodeCoordinateTencentGoogleGaodeType];
        [self.search searchWithReverseGeoCodeSearchOption:regeocoder];
        _isUpdated = YES;
    }
}

#pragma mark - ------------- MapView Search 相关代码 -------------

#pragma mark - 根据定位解析出位置信息

- (void)searchWithSearchOption:(QMSSearchOption *)searchOption didFailWithError:(NSError *)error
{
    _bottomToolBar.fromAddressLabel.text = @"从哪儿出发";
    _bottomToolBar.fromAddressLabel.textColor = COLORRGB(0xf39a00);
}

- (void)searchWithReverseGeoCodeSearchOption:(QMSReverseGeoCodeSearchOption *)reverseGeoCodeSearchOption didReceiveResult:(QMSReverseGeoCodeSearchResult *)reverseGeoCodeSearchResult
{
    if (reverseGeoCodeSearchResult.formatted_addresses) {
        _currentCity = reverseGeoCodeSearchResult.ad_info.city;
        _bottomToolBar.fromAddressLabel.text = reverseGeoCodeSearchResult.formatted_addresses.recommend;
        _bottomToolBar.fromAddressLabel.textColor = COLORRGB(0x63666b);
    } else {
        _bottomToolBar.fromAddressLabel.text = @"从哪儿出发";
        _bottomToolBar.fromAddressLabel.textColor = COLORRGB(0xf39a00);
    }
    
    [self setupAnnotation:YES];
}

#pragma mark -  地图打点
- (void)setupAnnotation:(BOOL)isFrom
{
    if (isFrom) {
        if (!_fromPointAnnotation) {
            _fromPointAnnotation = [[QPointAnnotation alloc] init];
        }
        for (QPointAnnotation *point in self.mapView.annotations) {
            if (_fromPointAnnotation == point) {
                [self.mapView removeAnnotation:_fromPointAnnotation];
            }
        }
        [self.mapView setCenterCoordinate:_fromLocation.coordinate];
        [_fromPointAnnotation setCoordinate:_fromLocation.coordinate];
        [self.mapView setZoomLevel:16.1 animated:YES];
        [self.mapView addAnnotation:_fromPointAnnotation];
    } else {
        if (!_toPointAnnotation) {
            _toPointAnnotation = [[QPointAnnotation alloc] init];
        }
        for (QPointAnnotation *point in self.mapView.annotations) {
            if (_toPointAnnotation == point) {
                [self.mapView removeAnnotation:_toPointAnnotation];
            }
        }
        [_toPointAnnotation setCoordinate:_toLocation.coordinate];
//        [self.mapView setCenterCoordinate:_toLocation.coordinate zoomLevel:16.1 animated:YES];
        [self.mapView addAnnotation:_toPointAnnotation];
    }
    if (_fromPointAnnotation && _toPointAnnotation) {
        QMSDrivingRouteSearchOption *driving = [[QMSDrivingRouteSearchOption alloc] init];
        [driving setFromCoordinate:_fromPointAnnotation.coordinate];
        [driving setToCoordinate:_toPointAnnotation.coordinate];
        //驾车路线规划支持多种规划策略（设置成综合最优策略）
        [driving setPolicyWithType:QMSDrivingRoutePolicyTypeRealTraffic];
        [self.search searchWithDrivingRouteSearchOption:driving];
    }
}

- (void)searchWithDrivingRouteSearchOption:(QMSDrivingRouteSearchOption *)drivingRouteSearchOption didRecevieResult:(QMSDrivingRouteSearchResult *)drivingRouteSearchResult
{
    _currentRoutPlan = [[drivingRouteSearchResult routes] firstObject];
    NSLog(@"距离：%@ | 时间：%@ | 路段数%d", [self humanReadableForDistance:_currentRoutPlan.distance], [self humanReadableForTimeDuration:_currentRoutPlan.duration],(int)_currentRoutPlan.steps.count);
    
    [self.mapView removeOverlays:self.mapView.overlays];
    NSUInteger count = _currentRoutPlan.polyline.count;
    CLLocationCoordinate2D coordinateArray[count];
    for (int i = 0; i < count; ++i)
    {
        [[_currentRoutPlan.polyline objectAtIndex:i] getValue:&coordinateArray[i]];
    }
    
    QPolyline *walkPolyline = [QPolyline polylineWithCoordinates:coordinateArray count:count];
    [self.mapView addOverlay:walkPolyline];
    [self guessChargeWithCoupon:_currentCoupon routPlan:_currentRoutPlan carStyle:_currentCar];
}

#pragma mark - 地图描绘路线

- (QOverlayView *)mapView:(QMapView *)mapView viewForOverlay:(id<QOverlay>)overlay
{
    QPolyline *polyline = (QPolyline *)overlay;
    QPolylineView *polylineView = [[QPolylineView alloc] initWithPolyline:overlay];
    
    polylineView.lineWidth = 5;
    
    if (polyline.dash)
    {
        polylineView.lineDashPattern = @[@3, @9];
        polylineView.strokeColor = [UIColor colorWithRed:0x55/255.f green:0x79/255.f blue:0xff/255.f alpha:1];
    }
    else
    {
        polylineView.lineDashPattern = nil;
        polylineView.strokeColor = [UIColor colorWithRed:0x00/255.f green:0x79/255.f blue:0xff/255.f alpha:1];
    }
    
    return polylineView;
}

#pragma mark - Utils

/*!
 *  @brief  格式化距离
 *
 *  @param distance 距离,单位是米
 *  @return 格式化字符串
 *  @detial
 *  (1) 567  ---> 567米
 *  (2) 1567 ---> 1.5公里
 *  (3) 2000 ---> 2公里
 */
- (NSString*) humanReadableForDistance:(double)distance
{
    NSString *humanReadable = nil;
    
    NSInteger theLength = (NSInteger)distance;
    
    // 米.
    if (theLength < 1000)
    {
        humanReadable = [NSString stringWithFormat:@"%ld米", (long)theLength];
    }
    // 公里.
    else
    {
#define WCLUtilityZeroEnd @".0"
        
        humanReadable = [NSString stringWithFormat:@"%.1f", theLength / 1000.0];
        
        BOOL zeroEnd = [humanReadable hasSuffix:WCLUtilityZeroEnd];
        
        // .0结尾, 去掉尾数.
        if (zeroEnd)
        {
            humanReadable = [humanReadable substringWithRange:NSMakeRange(0, humanReadable.length - WCLUtilityZeroEnd.length)];
        }
        
        humanReadable = [humanReadable stringByAppendingString:@"公里"];
    }
    
    return humanReadable;
}

/*!
 *  @brief  格式化时间
 *
 *  @param timeDuration 时间,单位是分钟
 *  @return 格式化字符串
 *  @detial
 *  (1) 10  ---> 10分钟
 *  (2) 120 ---> 2小时
 *  (3) 124 ---> 2小时4分钟
 */
- (NSString *)humanReadableForTimeDuration:(double) timeDuration
{
    NSString *humanReadable = nil;
    
    NSInteger theDuration = (NSInteger)timeDuration;
    
    // 分.
    if (theDuration < 60)
    {
        humanReadable = [NSString stringWithFormat:@"%ld分钟", (long)theDuration];
    }
    // 小时.
    else
    {
        humanReadable = [NSString stringWithFormat:@"%ld小时", (long)theDuration / 60];
        
        double remainder = fmod(theDuration, 60.0);
        
        if (remainder != 0)
        {
            NSString *remainderHumanReadable = [self humanReadableForTimeDuration:remainder];
            
            humanReadable = [humanReadable stringByAppendingString:remainderHumanReadable];
        }
    }
    
    return humanReadable;
}

@end

static char *QMSPolylineDashKey = "kQMSPolylineDashKey";

@implementation QPolyline (RouteExtention)

- (void)setDash:(BOOL)dash
{
    objc_setAssociatedObject(self, QMSPolylineDashKey, [NSNumber numberWithBool:dash], OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)dash
{
    NSNumber *dashNum = objc_getAssociatedObject(self, QMSPolylineDashKey);
    return [dashNum boolValue];
}

@end
