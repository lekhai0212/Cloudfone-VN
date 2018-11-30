//
//  KSettingViewController.m
//  linphone
//
//  Created by mac book on 10/4/15.
//
//

#import "KSettingViewController.h"
#import "LanguageViewController.h"
#import "SettingCell.h"

@interface KSettingViewController (){
    NSMutableArray *listTitle;
}
@end

@implementation KSettingViewController
@synthesize _iconBack, bgHeader, _lbHeader, _tbSettings, _viewHeader;

#pragma mark - UICompositeViewDelegate Functions
static UICompositeViewDescription *compositeDescription = nil;
+ (UICompositeViewDescription *)compositeViewDescription {
    if (compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:self.class
                                                              statusBar:nil
                                                                 tabBar:nil
                                                               sideMenu:nil
                                                             fullscreen:NO
                                                         isLeftFragment:YES
                                                           fragmentWith:nil];
        compositeDescription.darkBackground = true;
    }
    return compositeDescription;
}

- (UICompositeViewDescription *)compositeViewDescription {
    return self.class.compositeViewDescription;
}

#pragma mark - My Controller Delegate

- (void)viewDidLoad {
    [super viewDidLoad];
    // MY CODE HERE
    [self setupUIForView];
}

- (void)viewWillAppear:(BOOL)animated {
    // Tắt màn hình cảm biến
    
    [WriteLogsUtils writeForGoToScreen:@"KSettingViewController"];
    
    UIDevice *device = [UIDevice currentDevice];
    [device setProximityMonitoringEnabled: NO];
    
    [self showContentWithCurrentLanguage];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)_iconBackClicked:(id)sender {
    [[PhoneMainView instance] popCurrentView];
}

#pragma mark - My functions

- (void)showContentWithCurrentLanguage {
    _lbHeader.text = [[LinphoneAppDelegate sharedInstance].localization localizedStringForKey:@"Settings"];
    
    if ([LinphoneAppDelegate sharedInstance].enableForTest) {
        listTitle = [[NSMutableArray alloc] initWithObjects: [[LinphoneAppDelegate sharedInstance].localization localizedStringForKey:@"Change language"], [[LinphoneAppDelegate sharedInstance].localization localizedStringForKey:@"Call settings"], nil];
    }else{
        listTitle = [[NSMutableArray alloc] initWithObjects: [[LinphoneAppDelegate sharedInstance].localization localizedStringForKey:@"Change language"], nil];
    }
    
    [_tbSettings reloadData];
}

- (void)setupUIForView
{
    if (SCREEN_WIDTH > 320) {
        _lbHeader.font = [UIFont fontWithName:HelveticaNeue size:20.0];
    }else{
        _lbHeader.font = [UIFont fontWithName:HelveticaNeue size:18.0];
    }
    
    self.view.backgroundColor = [UIColor colorWithRed:(230/255.0) green:(230/255.0)
                                                 blue:(230/255.0) alpha:1.0];
    _tbSettings.backgroundColor = UIColor.clearColor;
    
    //  header view
    [_viewHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.height.mas_equalTo([LinphoneAppDelegate sharedInstance]._hRegistrationState);
    }];
    
    [bgHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.bottom.right.equalTo(_viewHeader);
    }];
    
    [_lbHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_viewHeader).offset([LinphoneAppDelegate sharedInstance]._hStatus);
        make.bottom.equalTo(_viewHeader);
        make.centerX.equalTo(_viewHeader.mas_centerX);
        make.width.mas_equalTo(200.0);
    }];
    
    [_iconBack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(_viewHeader);
        make.centerY.equalTo(_lbHeader.mas_centerY);
        make.width.height.mas_equalTo(HEADER_ICON_WIDTH);
    }];
    
    //  tableview
    [_tbSettings mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(_viewHeader.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
    _tbSettings.delegate = self;
    _tbSettings.dataSource = self;
    _tbSettings.scrollEnabled = NO;
    _tbSettings.separatorStyle = UITableViewCellSeparatorStyleNone;
}

#pragma mark - TableView Delegate & DataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return listTitle.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *identifier = @"SettingCell";
    SettingCell *cell = (SettingCell *)[tableView dequeueReusableCellWithIdentifier: identifier];
    if (cell == nil) {
        NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"SettingCell" owner:self options:nil];
        cell = topLevelObjects[0];
    }
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    cell._lbTitle.text = [listTitle objectAtIndex: indexPath.row];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    switch (indexPath.row) {
        case 0:{
            [[PhoneMainView instance] changeCurrentView:[LanguageViewController compositeViewDescription]
                                                   push:true];
            break;
        }
        case 1:{
            [[PhoneMainView instance] changeCurrentView:[SettingsView compositeViewDescription]
                                                   push:true];
            break;
        }
        default:
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 68.0;
}

@end
