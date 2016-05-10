//
//  ViewController.m
//  URLSession
//
//  Created by William on 16/4/26.
//  Copyright © 2016年 William. All rights reserved.
//

#import "ViewController.h"
#import <MediaPlayer/MediaPlayer.h>

#define _1M 1024*1024


@interface ViewController ()<NSURLSessionDownloadDelegate>
@property (nonatomic,strong) MPMoviePlayerController *moviePlayer;
@property (nonatomic,strong) NSURLSession *backgroundURLSession;

@property (nonatomic,strong) NSFileManager *manage;

@property (nonatomic,strong) NSString *docPath;

@property (nonatomic,strong) NSURLSessionDownloadTask *task;

@property (nonatomic,strong) NSData *fileData;

@property (nonatomic,strong) UILabel *lab;

@property (nonatomic,assign) long long int byte;

@end

@implementation ViewController
{
    NSString *dataPath;
    NSString *tmpPath;
    NSString *docFilePath;
}

-(MPMoviePlayerController *)moviePlayer{
    if (!_moviePlayer) {
        NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [docPath stringByAppendingPathComponent:@"file.mp4"];
        NSURL *url=[NSURL fileURLWithPath:filePath];
        _moviePlayer=[[MPMoviePlayerController alloc]initWithContentURL:url];
        _moviePlayer.view.frame=CGRectMake(0, 0, self.view.frame.size.width, 200);
        _moviePlayer.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
    }
    return _moviePlayer;
}
- (NSString *)docPath
{
    if (!_docPath)
    {
        _docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    }
    return _docPath;
}

- (NSFileManager *)manage
{
    if (!_manage)
    {
        _manage = [NSFileManager defaultManager];
    }
    return _manage;
}

- (NSURLSession *)backgroundURLSession
{
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *identifier = @"background";
        NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
        session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                              delegate:self
                                                         delegateQueue:[NSOperationQueue mainQueue]];
    });
    return session;
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    
    NSString *filePath = [self.docPath stringByAppendingPathComponent:@"file.mp4"];
    [self.manage moveItemAtURL:location toURL:[NSURL fileURLWithPath:filePath] error:nil];
    [self.manage removeItemAtPath:dataPath error:nil];
    [self.manage removeItemAtPath:docFilePath error:nil];
    _fileData = nil;
    NSLog(@"下载完成%@",filePath);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    _lab.text = [NSString stringWithFormat:@"下载中,进度为%.2f",totalBytesWritten*100.0/totalBytesExpectedToWrite];
    _byte+=bytesWritten;
    //1k = 1024字节,1M = 1024k,我这里定义的每下载1M保存一次,大家可以自行设置

    if (_byte > _1M)
    {
        [self downloadPause];
        _byte -= _1M;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
//    [self.moviePlayer play];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.moviePlayer.view];
    
    UIButton *start = [[UIButton alloc]initWithFrame:CGRectMake(60, 250, 40, 40)];
    [start setTitle:@"下载" forState:UIControlStateNormal];
    [start addTarget:self action:@selector(download) forControlEvents:UIControlEventTouchUpInside];
    start.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:start];
    
    UIButton *pause = [[UIButton alloc]initWithFrame:CGRectMake(160, 250, 40, 40)];
    [pause setTitle:@"暂停" forState:UIControlStateNormal];
    [pause addTarget:self action:@selector(pause) forControlEvents:UIControlEventTouchUpInside];
    pause.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:pause];
    
    dataPath = [self.docPath stringByAppendingPathComponent:@"file.db"];
    
    _lab = [[UILabel alloc]initWithFrame:CGRectMake(40, 300, 200, 40)];
    _lab.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:_lab];
}

- (void)pause
{
    
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        _fileData = resumeData;
        _task = nil;
        [resumeData writeToFile:dataPath atomically:YES];
        [self getDownloadFile];
    }];
}

- (void)download
{
    NSString *downloadURLString = @"http://221.226.80.142:8082/Myftp/jlsj/file/ssqr/fckUplodFiles/201603/201603231521474489.mp4";
    NSURL* downloadURL = [NSURL URLWithString:downloadURLString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL];
    
    _fileData = [NSData dataWithContentsOfFile:dataPath];
    
    if (_fileData)
    {
        NSString *Caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        [self.manage removeItemAtPath:Caches error:nil];
        [self MoveDownloadFile];
        _task = [self.backgroundURLSession downloadTaskWithResumeData:_fileData];
        
    }
    else
    {
        _task = [self.backgroundURLSession downloadTaskWithRequest:request];
    }
    
    _task.taskDescription = [NSString stringWithFormat:@"后台下载"];
    //执行resume保证开始了任务
    [_task resume];
    
    
}


//暂停下载,获取文件指针和缓存文件
- (void)downloadPause
{
    
    NSLog(@"%s",__func__);
    [_task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        _fileData = resumeData;
        _task = nil;
        [resumeData writeToFile:dataPath atomically:YES];
        [self getDownloadFile];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            //做完保存操作之后让他继续下载
            if (_fileData)
            {
                _task = [self.backgroundURLSession downloadTaskWithResumeData:_fileData];
                [_task resume];
            }
        });
    }];
}

//获取系统生成的文件
- (void)getDownloadFile
{
    //调用暂停方法后,下载的文件会从下载文件夹移动到tmp文件夹
    NSArray *paths = [self.manage subpathsAtPath:NSTemporaryDirectory()];
    NSLog(@"%@",paths);
    for (NSString *filePath in paths)
    {
        if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
        {
            tmpPath = [self.docPath stringByAppendingPathComponent:filePath];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            //tmp中的文件随时有可能给删除,移动到安全目录下防止被删除
            [self.manage copyItemAtPath:path toPath:tmpPath error:nil];
            
            //建议创建一个plist表来管理,可以通过task的response的***name获取到文件名称,kvc存储或者直接建立数据库来进行文件管理,不然文件多了可能会管理混乱;
        }
    }
}

//讲道理这个和上面的应该封装下
- (void)MoveDownloadFile
{
    NSArray *paths = [self.manage subpathsAtPath:_docPath];
    
    for (NSString *filePath in paths)
    {
        if ([filePath rangeOfString:@"CFNetworkDownload"].length>0)
        {
            docFilePath = [_docPath stringByAppendingPathComponent:filePath];
            NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:filePath];
            //反向移动
            [self.manage copyItemAtPath:docFilePath toPath:path error:nil];
            
            //建议创建一个plist表来管理,可以通过task的response的***name获取到文件名称,kvc存储或者直接建立数据库来进行文件管理,不然文件多了可能会管理混乱;
        }
    }
    NSLog(@"%@,%@",paths,[self.manage subpathsAtPath:NSTemporaryDirectory()]);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    NSLog(@"%s", __func__);

}


@end
