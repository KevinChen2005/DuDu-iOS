//
//  MainViewController.h
//  DuDu
//
//  Created by i-chou on 11/4/15.
//  Copyright © 2015 i-chou. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TopToolBar.h"
#import "BottomToolBar.h"
#import "TimePicker.h"
#import "MenuTableViewController.h"
#import "OrderModel.h"
#import "GeoAndSuggestionViewController.h"
#import <QMapKit/QMapKit.h>
#import <QMapSearchKit/QMapSearchKit.h>
#import "CouponVC.h"
#import "adModel.h"

@interface MainViewController : BaseViewController
<TopToolBarDelegate,
BottomToolBarDelegate,
TimePickerDelegate,
QMapViewDelegate,
QMSSearchDelegate,
GeoAndSuggestionViewControllerDelegate,
LoginVCDelegate,
CouponVCDelegate
>

+ (instancetype)sharedMainViewController;

@property (nonatomic, strong) QMapView      *mapView;
@property (nonatomic, strong) QMSSearcher   *search;
@property (nonatomic, strong) QUserLocation *fromLocation;
@property (nonatomic, strong) QUserLocation *toLocation;
@property (nonatomic, strong) TopToolBar    *topToolBar;
@property (nonatomic, strong) NSArray       *carStyles;
@property (nonatomic, strong) CarModel      *currentCar;
@property (nonatomic, strong) adModel       *adInfo;
@property (nonatomic, strong) OrderStore    *orderStore;

- (void)clearData;
- (void)locateMapView;

@end

@interface QPolyline(RouteExtention)

- (void)setDash:(BOOL)dash;

- (BOOL)dash;

@end
