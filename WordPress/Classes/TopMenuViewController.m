//
//  TopMenuViewController.m
//  hpbpad
//
//  Created by Ryo Yagyuda on 2013/06/26.
//

#import "TopMenuViewController.h"

#define kSelectedBlogChanged @"kSelectedBlogChanged"

@interface TopMenuViewController ()

@end

@implementation TopMenuViewController {
    CGFloat _panOrigin;
    CGFloat _stackOffset;
    BOOL _isAppeared;
    BOOL _isShowingPoppedIcon;
    BOOL _panned;
    BOOL _pushing;
    NSArray *_mpArray;          // テンプレート情報の配列
    NSArray *_templateArray;    // テンプレートのviewの配列
    // viewからindexを取得するために、同じ順序になるようにviewの配列を作っている // TODO:一つの配列で管理する等
    
    NSInteger _currentThumbnail;
    NSInteger _currentPostType;
}

@synthesize postButton;
@synthesize photoButton;
@synthesize listButton;
@synthesize webViewLoadingCount;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    // Do any additional setup after loading the view from its nib.
    
    // 半透明レイヤー、最初は非表示
    [self hideOverViewAnimated:NO switchTitleImage:NO];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self updateLayout];
    
    self.transparentBGView.backgroundColor = [UIColor colorWithRed:75.0/255.0 green:72.0/255.0 blue:72.0/255.0 alpha:204.0/255.0];
    
    // mpロゴ位置
    CGFloat mpLogoX = (self.contentView.frame.size.width/2) - (self.mpLogoView.frame.size.width/2);
    self.mpLogoView.frame = CGRectMake(mpLogoX, self.mpLogoView.frame.origin.y, self.mpLogoView.frame.size.width, self.mpLogoView.frame.size.height);
    
    // 仮データ　//TODO: 本番ではWebAPI経由で取得
    NSArray *keys = [NSArray arrayWithObjects:@"imageURL", @"pageURL", nil];
    NSArray *objects = [NSArray arrayWithObjects:@"mp_1_mock", @"http://www.justsystems.com/jp/", nil];
    NSDictionary *dict = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    NSArray *objects2 = [NSArray arrayWithObjects:@"mp_2_mock", @"http://www.google.co.jp/", nil];
    NSDictionary *dict2 = [NSDictionary dictionaryWithObjects:objects2 forKeys:keys];
    NSArray *objects3 = [NSArray arrayWithObjects:@"mp_2_mock", @"http://wordpress.com/", nil];
    NSDictionary *dict3 = [NSDictionary dictionaryWithObjects:objects3 forKeys:keys];
    _mpArray = [NSArray arrayWithObjects:dict,dict2,dict3,dict,dict, nil];
    
    // mp画像をセット
    _templateArray = [NSArray array];
    UIImageView *imageView = nil;
    UIImageView *outerImageView = nil;
    UIImage *image = nil;
    NSString *imageURL = nil;
    UIImage *outerImage = [UIImage imageNamed:@"template"];
    CGFloat logoHeight = self.mpLogoView.frame.origin.y + self.mpLogoView.frame.size.height + 7;
    CGFloat y = logoHeight;
    CGFloat size = self.contentView.frame.size.width - 6;
    for (int i=0; i<5; i++) {
        // 外枠のimageView
        outerImageView = [[UIImageView alloc] initWithImage:outerImage];
        outerImageView.frame = CGRectMake(3, y, size, size);
        outerImageView.backgroundColor = [UIColor clearColor];
        outerImageView.userInteractionEnabled = YES;
        
        // 内側（テンプレート画像本体）のimageView
        imageURL = [[_mpArray objectAtIndex:i] valueForKey:@"imageURL"];
        image = [UIImage imageNamed:imageURL];     //TODO: 本来はファイル名でなくURL叩いて取得
        imageView = [[UIImageView alloc] initWithImage:image];
        imageView.frame = CGRectMake(3, 3, size-6, size-6);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.userInteractionEnabled = YES;
        [imageView addGestureRecognizer:[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(onTappedTemplate:)]];
        
        // 外枠にテンプレートのサムネイルをのせる
        [outerImageView addSubview:imageView];
        // contentViewのサイズを調整
        [self.contentView addSubview:outerImageView];
        // imageViewを配列にセットしておく(あとでviewをもとにmpArrayの情報を取得する目的)
        _templateArray = [_templateArray arrayByAddingObject:imageView];
        y = y + size + 3;
    }
    self.contentView.frame = CGRectMake(self.contentView.frame.origin.x, self.contentView.frame.origin.y, self.contentView.frame.size.width, y);
    [self.scrollView setContentSize:self.contentView.frame.size];
    
    
    // タイトルロゴのタップでも、半透明レイヤーを降ろす。
    [self.titleImageView setUserInteractionEnabled:YES];
    UITapGestureRecognizer *tapper = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showOverView)];
    [self.titleImageView addGestureRecognizer:tapper];
    
    NSArray* originalRecognizers = self.navigationController.navigationBar.gestureRecognizers;
    NSArray* recognizers = [originalRecognizers arrayByAddingObject:self.panGestureRecognizer];
    self.navigationController.navigationBar.gestureRecognizers = recognizers;
    self.overViewPanHandle.gestureRecognizers = [NSArray arrayWithObjects:self.panGestureRecognizer,nil];
}

- (void)updateLayout{
    CGFloat handleHeight = 45;
    CGRect buttonsRect = self.buttonsView.frame;
    CGSize barSize = self.navigationController.navigationBar.bounds.size;
    
    CGFloat height = 0; CGFloat width = 0;
    UIInterfaceOrientation o =  [[UIApplication sharedApplication] statusBarOrientation];
    if(o == UIInterfaceOrientationPortrait || o == UIInterfaceOrientationPortraitUpsideDown){
        width = [[UIScreen mainScreen] applicationFrame].size.width;
        height = [[UIScreen mainScreen] applicationFrame].size.height - barSize.height;
    } else if (o == UIInterfaceOrientationLandscapeLeft || o == UIInterfaceOrientationLandscapeRight){
        width = [[UIScreen mainScreen] applicationFrame].size.height;
        height = [[UIScreen mainScreen] applicationFrame].size.width - barSize.height;
    }
    
    if (IS_IPAD) {
        width = width - [[self sidebarViewController] view].bounds.size.width;
        if (o == UIInterfaceOrientationLandscapeLeft || o == UIInterfaceOrientationLandscapeRight){
            width = height + 40 - [[self sidebarViewController] view].bounds.size.width;
        }
    }
    CGRect contentRect = CGRectMake(0,0,width,height);
    
    self.scrollView.frame = contentRect;
    self.overView.frame = contentRect;
    self.transparentBGView.frame = contentRect;
    self.contentView.frame = CGRectMake(0, 0, contentRect.size.width, self.contentView.frame.size.height);
    self.overViewPanHandle.frame = CGRectMake(0, contentRect.size.height-self.overViewPanHandle.frame.size.height,
                                               contentRect.size.width, self.overViewPanHandle.bounds.size.height);
    self.buttonsView.frame = CGRectMake((contentRect.size.width/2) - (buttonsRect.size.width/2), contentRect.size.height-buttonsRect.size.height-handleHeight, buttonsRect.size.width, buttonsRect.size.height);
    self.thumbnailPagerView.frame = CGRectMake(0, 9, contentRect.size.width, self.buttonsView.frame.origin.y);
    self.overViewPanHandleImage.frame = CGRectMake((self.overViewPanHandle.bounds.size.width/2) - (self.overViewPanHandleImage.bounds.size.width/2),
                                                   (self.overViewPanHandle.bounds.size.height/2),
                                                   self.overViewPanHandleImage.bounds.size.width,
                                                   self.overViewPanHandleImage.bounds.size.height);
    if(IS_IPAD){
        [self.view addSubview:self.titleImageView];
        CGFloat logox = width - self.titleImageView.bounds.size.width;
        self.titleImageView.frame = CGRectMake(logox,0,self.titleImageView.bounds.size.width,self.titleImageView.bounds.size.height);
    }
    
    [self.scrollView addSubview:self.contentView];
    [self.scrollView setContentSize:self.contentView.frame.size];
    [self.view addSubview:self.scrollView];
    [self.view addSubview:self.overView];
    
    if(IS_IPAD){
        [self.view bringSubviewToFront:self.titleImageView];
    } else {
        self.navigationItem.titleView = self.titleImageView;
    }
    
    [self initThumbnailPagerView];
}

// サムネイル切り替えの準備
- (void)initThumbnailPagerView{
    self.thumbnailPagerView.topMenuViewController = self;
    self.thumbnailPagerView.items = [self blogs];
    [self.thumbnailPagerView reset];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setView:nil];
    [self setPostButton:nil];
    [self setPhotoButton:nil];
    [self setListButton:nil];
    [self setPanGestureRecognizer:nil];
    [self setPostTypePagerView:nil];
    [self setTransparentBGView:nil];
    [self setMpLogoView:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    [self updateLayout];
}


- (void)onTappedTemplate:(UITapGestureRecognizer *)sender{
    NSUInteger *index = [_templateArray indexOfObject:sender.view];
    NSDictionary *dict = [_mpArray objectAtIndex:index];
    NSString *URL = [dict valueForKey:@"pageURL"];
    //[[UIApplication sharedApplication] openURL:[NSURL URLWithString:URL]];
    [self showWebviewWithURL:URL];
}
- (IBAction)onTouchUpPostButton:(UIButton *)sender {
    [self showPost];
}
- (IBAction)onTouchUpPhotoButton:(UIButton *)sender {
    [self showPhoto];
}
- (IBAction)onTouchUpListButton:(UIButton *)sender {
    [self showList];
}

// 半透明レイヤーのスライド動作。サイドバーを参考に
- (IBAction)onPanOverView:(UIPanGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        _panned = YES;
    }
    CGPoint p = [sender translationInView:self.overView];
    CGFloat offset = _panOrigin - p.y;
    /*
     Step 1: setup boundaries
     */
    
    /*
    CGFloat minSoft = 0.0f;
    CGFloat minHard = 0.0f;
    CGFloat maxSoft = DETAIL_HEIGHT;
    CGFloat maxHard = DETAIL_HEIGHT;
    CGFloat limitOffset = MAX(minSoft, MIN(maxSoft, offset));
    CGFloat diff = ABS(ABS(offset) - ABS(limitOffset));
    // if we're outside the allowed bounds
    if (diff > 0) {
        // Reduce the dragged distance
        diff = diff / logf(diff + 1) * 2;
        offset = limitOffset + (offset < limitOffset ? -diff : diff);
    }
    offset = MAX(minHard, MIN(maxHard, offset));
     */
    
    /*
     Step 2: calculate each view position
     */
    [self setStackOffset:offset withVelocity:0];

    /*
     Step 3: when released, calculate final positions
     */
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGFloat velocity = [sender velocityInView:self.overView].y;
        if (ABS(velocity) < 300) {
            //if (offset < DETAIL_LEDGE_OFFSET / 3) {
            if (offset < self.overView.frame.size.height / 3) {
                [self showOverView];
            } else {
                [self hideOverView];
            }
        } else if (velocity > 0) {
            [self showOverView];
        } else {
            [self hideOverView];
        }
    }
    
}

- (void)setStackOffset:(CGFloat)offset withVelocity:(CGFloat)velocity{
    velocity = MAX(-1000, MIN(1000, velocity * 0.3)); // limit the velocity
    CALayer *viewLayer = self.view.layer;
    [viewLayer removeAllAnimations];
    
    CGFloat remainingOffset = offset;

    CGFloat usedOffset = remainingOffset;
    //CGFloat viewY = DETAIL_LEDGE_OFFSET - usedOffset;
    CGFloat viewY = DETAIL_HEIGHT - usedOffset;
    
    [self animateView:self.view toOffset:viewY withVelocity:velocity];
    remainingOffset -= usedOffset;
    
    _stackOffset = offset - remainingOffset;
    //[self partiallyVisibleViews];
}

- (void)animateView:(UIView *)view toOffset:(CGFloat)offset withVelocity:(CGFloat)velocity {
    //view = [self overView];
    CALayer *viewLayer = self.overView.layer;
    [viewLayer removeAllAnimations];
    float viewOffset = MAX(0, MIN(offset, self.overView.bounds.size.height));
    
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position.y"];
    
    CGPoint startPosition = viewLayer.position;
    CGPoint endPosition = CGPointMake(startPosition.x, viewOffset-(viewLayer.frame.size.height * 0.5f));
    CGFloat distance = ABS(startPosition.y - endPosition.y);
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:4];
    NSMutableArray *timingFunctions = [NSMutableArray arrayWithCapacity:3];
    NSMutableArray *keyTimes = [NSMutableArray arrayWithCapacity:4];
    [keyTimes addObject:[NSNumber numberWithFloat:0.f]];
    [values addObject:[NSNumber numberWithFloat:startPosition.y]];
    CGFloat overShot = 0, duration = ABS(distance/velocity);
    CAMediaTimingFunction *easeInOut = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [timingFunctions addObject:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    
    if(ABS(velocity) > PANEL_MINIMUM_OVERSHOT_VELOCITY && (!IS_IPAD || distance > 10.f)){
        [timingFunctions addObject:easeInOut];
        velocity *= 0.25f;

        overShot = 22.f * (velocity * PANEL_OVERSHOT_FRICTION);
//        distance += ABS(overShot); // added but never used?
        CGFloat overShotDuration = ABS(overShot/(velocity * (1-PANEL_OVERSHOT_FRICTION))) * 1.25;
        [keyTimes addObject:[NSNumber numberWithFloat:(duration/(duration+overShotDuration))]];
        duration += overShotDuration;
        [values addObject:[NSNumber numberWithFloat:endPosition.y + overShot]];
    } else {
        // nothing special, just slide
        duration = 0.2f;
        
    }
    [keyTimes addObject:[NSNumber numberWithFloat:1.f]];
    
    [values addObject:[NSNumber numberWithFloat:endPosition.y]];
    
    animation.values = values;
    animation.timingFunctions = timingFunctions;
    animation.keyTimes = keyTimes;
    animation.duration = duration;
        
    [viewLayer addAnimation:animation forKey:@"position"];
    viewLayer.position = endPosition;
}
- (void)hideOverView {
    [self hideOverViewAnimated:YES];
    _panOrigin = DETAIL_HEIGHT;
}

- (void)hideOverViewAnimated:(BOOL)animated {
    [self hideOverViewAnimated:animated switchTitleImage:YES];
}
- (void)hideOverViewAnimated:(BOOL)animated switchTitleImage:(BOOL)switchTitleImage {
    [UIView animateWithDuration:OPEN_SLIDE_DURATION(animated) delay:0 options:0 | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self setStackOffset:DETAIL_HEIGHT withVelocity:0.0f];
        //[self disableDetailView];
    } completion:^(BOOL finished) {
        if(!switchTitleImage){ return; }
        
        if(IS_IPAD){
            [self.titleImageView setHidden:NO];
        }
        self.titleImageView.image = [UIImage imageNamed:@"logo_up"];
     }];
}
- (void)showOverView {
    [self showOverViewAnimated:YES];
    _panOrigin = 0;
}
- (void)showOverViewAnimated:(BOOL)animated {
    [self showOverViewAnimated:animated switchTitleImage:YES];
}
- (void)showOverViewAnimated:(BOOL)animated switchTitleImage:(BOOL)switchTitleImage {
    [UIView animateWithDuration:OPEN_SLIDE_DURATION(animated) delay:0 options:0 | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self setStackOffset:0.0f withVelocity:0.0f];
    } completion:^(BOOL finished) {
        if(!switchTitleImage){ return; }
        
        if(IS_IPAD){
            [self.titleImageView setHidden:YES];
        }
        self.titleImageView.image = [UIImage imageNamed:@"logo"];
    }];
}

- (IBAction)onTapRightNavigationItem:(id)sender {
    [self showOverView];
}

// 投稿する
- (void)showPost {
    [self showList];
    if ([self.panelNavigationController.topViewController respondsToSelector:@selector(showAddPostView)]) {
        [self.panelNavigationController.topViewController performSelector:@selector(showAddPostView)];
    }
}

// 写真からの投稿
- (void)showPhoto {
    /*
    if (quickPhotoActionSheet) {
        // Dismiss the previous action sheet without invoking a button click.
        [quickPhotoActionSheet dismissWithClickedButtonIndex:-1 animated:NO];
    }
    */
	UIActionSheet *actionSheet = nil;
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        if ([[CameraPlusPickerManager sharedManager] cameraPlusPickerAvailable]) {
            actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
                                                      delegate:(id)[self sidebarViewController]
                                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                        destructiveButtonTitle:nil 
                                             otherButtonTitles:NSLocalizedString(@"Add Photo from Library", @""),NSLocalizedString(@"Take Photo", @""),NSLocalizedString(@"Add Photo from Camera+", @""), NSLocalizedString(@"Take Photo with Camera+", @""),nil];
        } else {
            actionSheet = [[UIActionSheet alloc] initWithTitle:@"" 
                                                      delegate:(id)[self sidebarViewController]
                                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                        destructiveButtonTitle:nil 
                                             otherButtonTitles:NSLocalizedString(@"Add Photo from Library", @""),NSLocalizedString(@"Take Photo", @""),nil];            
        }
	} else {
        [[self sidebarViewController] showQuickPhoto:UIImagePickerControllerSourceTypePhotoLibrary useCameraPlus:NO withImage:nil];
        return;
	}
    
    actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
//    if (IS_IPAD) {
//        [actionSheet showFromRect:quickPhotoButton.frame inView:utililtyView animated:YES];
//    } else {
        [actionSheet showInView:self.panelNavigationController.view];        
//    }
    //quickPhotoActionSheet = actionSheet;
}

// 投稿一覧表示
- (void)showList {
    NSInteger row = self.postTypePagerView.currentPosition;
    NSInteger sec = self.thumbnailPagerView.currentPosition +1;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:sec];
    [[self sidebarViewController] processRowSelectionAtIndexPath:indexPath];
    [[self sidebarViewController].tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self sidebarViewController].currentIndexPath = indexPath;
}

// サイトを見る
- (void)showPreview {
    [WPMobileStats trackEventForWPCom:StatsPropertySidebarSiteClickedViewSite];
    //Blog *blog = [self sidebarViewController].openSection.blog;
    Blog *blog = [self blog];
    NSString *blogURL = blog.url;
    if (![blogURL hasPrefix:@"http"]) {
        blogURL = [NSString stringWithFormat:@"http://%@", blogURL];
    } else if ([blog isWPcom] && [blog.url rangeOfString:@"wordpress.com"].location == NSNotFound) {
        blogURL = [blog.xmlrpc stringByReplacingOccurrencesOfString:@"xmlrpc.php" withString:@""];
    }
    [self showWebviewWithURL:blogURL];
    if( [blog isPrivate] ) {
        WPWebViewController *webViewController = (WPWebViewController *)[[self panelNavigationController] detailViewController];
        [webViewController setUsername:blog.username];
        [webViewController setPassword:blog.password];
        [webViewController setWpLoginURL:[NSURL URLWithString:blog.loginUrl]];
    }
    return;
}

// URLを指定してWebviewを開く
- (void)showWebviewWithURL:(NSString *)URL {
    //check if the same site already loaded
    if ([self.panelNavigationController.detailViewController isMemberOfClass:[WPWebViewController class]]
        &&
        [((WPWebViewController*)self.panelNavigationController.detailViewController).url.absoluteString isEqual:URL]
        ) {
        if (IS_IPAD) {
            [self.panelNavigationController showSidebar];
        } else {
            [self.panelNavigationController popToRootViewControllerAnimated:NO];
            [self.panelNavigationController closeSidebar];
        }
    } else {
        WPWebViewController *webViewController = [[WPWebViewController alloc] init];
        [webViewController setUrl:[NSURL URLWithString:URL]];
        [self.panelNavigationController setDetailViewController:webViewController closingSidebar:NO];
    }
    if (IS_IPAD) {
        //[SoundUtil playSwipeSound];
    }
}

// SidebarViewcontrollerを取得する
- (SidebarViewController *)sidebarViewController {
    SidebarViewController *sidebarViewController = (SidebarViewController *)self.panelNavigationController.masterViewController;
    return sidebarViewController;
}
- (NSArray *)blogs {
    NSArray *blogs = [[self sidebarViewController] blogs];
    return blogs;
}
- (Blog *)blog {
    //Blog* blog = [[self blogs] objectAtIndex:_currentThumbnail];
    NSInteger index = self.thumbnailPagerView.currentPosition;
    Blog* blog = [[self blogs] objectAtIndex:index];
    return blog;
}
-(NSArray *)postTypes {
    // 並べ替えたりしてるので、postListsから取得する必要がある。
    //NSArray *postTypes = [[self blog].postTypes allObjects];
    NSArray *postTypes = [[self blog].postLists valueForKeyPath:@"postType"];
    return postTypes;
}
-(PostType *)postType {
    NSInteger index = self.postTypePagerView.currentPosition;
    PostType* postType = [[self postTypes] objectAtIndex:index];
    return postType;
}

@end
