//
//  PublishViewController.m
//  demo
//
//  Created by 张俊 on 08/04/2017.
//  Copyright © 2017 ksyun. All rights reserved.
//

#import "NavigateView.h"
#import "UIImage+Add.h"
#import "KSYPlayerVC.h"
#import "PublishViewController.h"

// 获取KS3Token地址
#define kKS3AuthURI     @"http://10.64.7.106:8980/api/upload/ks3/sig"

@interface PublishViewController ()<KSYMediaEditorDelegate>

@property(nonatomic, strong)NavigateView *naviView;

@property(nonatomic, strong)UIImageView *coverView;

@property(nonatomic, strong)NSString *path;

@property(nonatomic, strong)MBProgressHUD *hudView;

//@property(nonatomic, strong)KS3UploadMgr *uploadMgr;

@end

@implementation PublishViewController

- (instancetype)initWithUrl:(NSString *)path
{
    if (self = [super init]){
        NSLog(@"path:%@", path);
        self.path = path;
    }
    return self;

}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.naviView = [[NavigateView alloc] init];
    self.naviView.frame = CGRectMake(0, 0, kScreenSizeWidth, 64);
    self.naviView.backgroundColor = [UIColor  blackColor];
    //NSURL *sampleURL = [[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"];
    UIImage *image = [UIImage thumbnailImageForVideo:[NSURL fileURLWithPath:self.path] atTime:1.5];
    if (image){
        self.coverView = [[UIImageView alloc] initWithImage:image];
        //self.coverView.contentMode = UIViewContentModeScaleToFill;
        self.coverView.bounds = CGRectMake(0, 0, kScreenSizeWidth*3/4, kScreenSizeWidth*3/4*image.size.height/image.size.width);
        self.coverView.center = self.view.center;
        self.coverView.layer.borderWidth = 8;
        self.coverView.layer.borderColor = [UIColor grayColor].CGColor;
        [self.view addSubview:self.coverView];
    }
    //self.path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/KSYShortVideoCache/1491965295.mp4"];


    
    self.view.backgroundColor = [UIColor whiteColor];
    WeakSelf(PublishViewController);
    self.naviView.onEvent = ^(int idx, int ext){
        if (idx == 0){//取消
            [weakSelf onCancel];
        }
        if (idx == 1){//发布
            [weakSelf onPublish];
        }
    
    };
    
    [self.view addSubview:self.naviView];
    
    
    
    
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)onCancel
{
    //TODO
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onPublish
{
    //TODO
    [self getKS3AuthInfo];
    _hudView = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    _hudView.mode = MBProgressHUDModeAnnularDeterminate;
    _hudView.label.text = @"正在上传中";
}



#pragma mark - ks3 auth

/**
 向APP Server请求ks3Token
 */
- (void)getKS3AuthInfo{
    
    KSYMediaEditor *editor = [KSYMediaEditor sharedInstance];
    editor.delegate = self;
    NSString *bundleId = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
    NSString *objKey = [NSString stringWithFormat:@"%@/%ld.mp4",bundleId,time(NULL)];
    
    NSDictionary *uploadparams = @{KSYUploadBucketName : @"ksvsdemo",
                                   KSYUploadObjKey : objKey
                                   };
    __weak typeof(self) weakSelf = self;
    [editor setUploadParams:uploadparams block:^(NSDictionary *params, KSYUploadWithTokenBlock block) {
        [weakSelf requestKS3TokenWith:params complete:^(NSString *ks3Token, NSString *strDate) {
            block(ks3Token, strDate);
        }];
    }];
}

- (void)requestKS3TokenWith:(NSDictionary *)dict complete:(void(^)(NSString *ks3Token, NSString *strDate))complete{
    NSString *strUrl = [[NSString stringWithFormat:@"%@?"
                         "headers=%@"
                         "&md5=%@"
                         "&res=%@"
                         "&type=%@"
                         "&verb=%@",
                         kKS3AuthURI,
                         [dict valueForKey:@"Headers"],
                         [dict valueForKey:@"ContentMd5"],
                         [dict valueForKey:@"Resource"],
                         [dict valueForKey:@"ContentType"],
                         [dict valueForKey:@"HttpMethod"]
                         ] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    
    static NSString * const kAFCharactersGeneralDelimitersToEncode = @":#[]@"; // does not include "?" or "/" due to RFC 3986 - Section 3.4
    static NSString * const kAFCharactersSubDelimitersToEncode = @"!$&'()*+,;=";
    
    NSMutableCharacterSet * allowedCharacterSet = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
    [allowedCharacterSet removeCharactersInString:[kAFCharactersGeneralDelimitersToEncode stringByAppendingString:kAFCharactersSubDelimitersToEncode]];
    static NSUInteger const batchSize = 50;
    
    NSUInteger index = 0;
    NSMutableString *encodedUrl = @"".mutableCopy;
    
    while (index < strUrl.length) {
        NSUInteger length = MIN(strUrl.length - index, batchSize);
        NSRange range = NSMakeRange(index, length);
        
        range = [strUrl rangeOfComposedCharacterSequencesForRange:range];
        NSString *substring = [strUrl substringWithRange:range];
        NSString *encoded = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacterSet];
        [encodedUrl appendString:encoded];
        
        index += range.length;
    }
    
    NSURL *url = [NSURL URLWithString:encodedUrl];

    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"GET";
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            if (dict && [[dict valueForKey:@"RetCode"] integerValue] == 0) {
                NSString *ks3Token = dict[@"Authorization"];
                NSString *strDate = dict[@"Date"];
                
                if (complete){
                    complete(ks3Token, strDate);
                }
            }
        }else {
            if (complete){
                complete(nil, nil);
            }
        }
    }] resume];

}

#pragma mark - KS3 delegate


- (void)onUploadProgressChanged:(float)value
{
    _hudView.progress = value;
}

- (void)onKS3UploadFinish:(NSString *)path
{
    WeakSelf(PublishViewController);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_hudView hideAnimated:YES];
        KSYPlayerVC *vc = [[KSYPlayerVC alloc] initWithURL:[NSURL URLWithString:path]];
        
        [weakSelf presentViewController:vc animated:YES completion:nil];
        
    });
}



- (void)onErrorOccur:(KSYMediaEditor*)editor err:(KSYStatusCode)err  extraStr:(NSString*)extraStr
{
    [_hudView hideAnimated:YES];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    // Set the text mode to show only text.
    hud.mode = MBProgressHUDModeText;
    hud.label.text = extraStr?:@"未知错误";
    // Move to bottm center.
    hud.offset = CGPointMake(0.f, MBProgressMaxOffset);
    
    [hud hideAnimated:YES afterDelay:2.f];
    
}

-(void)dealloc
{

}

@end
