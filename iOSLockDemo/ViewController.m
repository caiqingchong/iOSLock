//
//  ViewController.m
//  iOSLockDemo
//
//  Created by 张张凯 on 2018/2/11.
//  Copyright © 2018年 TRS. All rights reserved.
//

#import "ViewController.h"
#import <libkern/OSAtomic.h>
@interface ViewController (){
    NSMutableArray *_elements;
    NSLock *_lock;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSNumber *number = @(1);
    NSNumber *thisPtrWillGoToNil = number;
    
//    @synchronized (thisPtrWillGoToNil) {
//        thisPtrWillGoToNil = nil;
//    }
//
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^ {
//
//        NSCAssert(![NSThread isMainThread], @"Must be run on background thread");
//
//        @synchronized (number) {
//            NSLog(@"This line does indeed get printed to stdout");
//        }
//
//    });
    
//    [self GDCAndLock];
    
    
//    [self tryLockAndDate];
    
//    [self useConditionLock];
    
    //条件锁
//    [self nsconditionlock];
    
    //锁的唤醒
//    [self nsCondition];
    
    //信号量
    [self useDispatch_semaphore];


}

/*
 一、NSLock上锁、解锁
  我们初始化一个 _elements 数组和一个 NSLock 实例。这个类还有个 push: 方法，它先获取锁、然后向数组中插入元素、最终释放锁。可能会有许多线程同时调用 push: 方法，但是 [_elements addObject:element] 这行代码在任何时候将只会在一个线程上运行。
  原理：NSLock实现了最基本的互斥锁，遵循NSLocking协议，通过lock和unLock来进行锁定于解锁。当一个线程访问的时候，该线程获得锁，其他线程访问的时候，将被操作系统挂起，知道该线程释放锁，其他线程才能对其进行访问，从而确保线程安全。如果连续锁定，则会造成死锁问题。
 */
/*
 A :lock的最简单使用
 */
- (void)initLock{
    //1、对锁进行初始化
    _elements = [NSMutableArray array];
    _lock = [[NSLock alloc] init];
}

- (void)push:(id)element{
    //2、上锁
    [_lock lock];
    [_elements addObject:element];
    //3、解锁
    [_lock unlock];
    
}

/*
 B :lock的结合GCD多线程调用使用
 */
- (void)GDCAndLock{
    _lock = [[NSLock alloc]init];
    
    //在多个线程中调用。由于使用锁的线程锁是没有执行完毕的，所以其他显线程不能调用，直到执行完毕后，才允许其他线程调用。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"1");
        [self lockFounction:[NSThread currentThread] num: 1];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"2");
        [self lockFounction:[NSThread currentThread] num: 2];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"3");
        [self lockFounction:[NSThread currentThread] num: 3];
    });
    
  
}
- (void)lockFounction:(NSThread *)thread num:(NSInteger) num {
    [_lock lock];
    NSLog(@"thread - %@, num - %ld", thread, num);
    sleep(5);
    [_lock unlock];
}

/*
 C :lock的tryLock和lockBeforeDate两个方法的使用。
 ，前一个方法会尝试加锁，如果锁不可用(已经被锁住)，刚并不会阻塞线程，并返回NO。lockBeforeDate:方法会在所指定Date之前尝试加锁，如果在指定时间之前都不能加锁，则返回NO。
    tryLock会尝试加锁，如果所不可用（已经被锁），并不会阻塞线程，并发挥NO。lockBeforeDate:会在指定Date之前尝试加锁，如果在指定时间之前不能加锁，则会返回NO。
 */

- (void)tryLockAndDate{
    _lock = [[NSLock alloc]init];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //lockBeforeDate会在指定的时间之前加锁，所以已经使用过[_lock lock]了.下面相当于在gdang前时间之前上锁了。
        [_lock lockBeforeDate:[NSDate date]];
        NSLog(@"1需要线程同步的操作1 开始");
        sleep(2);
        NSLog(@"1需要线程同步的操作1 结束");
        [_lock unlock];
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        if ([_lock tryLock]) {//尝试获取锁，如果获取不到返回NO，不会阻塞该线程
            NSLog(@"2锁可用的操作");
            [_lock unlock];
        }else{
            NSLog(@"2锁不可用的操作");
        }
        NSDate *date = [[NSDate alloc] initWithTimeIntervalSinceNow:3];
        if ([_lock lockBeforeDate:date]) {
            //尝试在未来的3s内获取锁，并阻塞该线程，如果3s内获取不到恢复线程, 返回NO,不会阻塞该线程
            NSLog(@"2没有超时，获得锁");
            [_lock unlock];
        }else{
            NSLog(@"2超时，没有获得锁");
        }
    });
    
}



/*
 知识网址：http://yulingtianxia.com/blog/2015/11/01/More-than-you-want-to-know-about-synchronized/
 二、@synchronized
 是OC层面的锁，synchronized block 与 [_lock lock] & [_lock unlock] 效果相同，但语法更加简洁可读，但代价是性能的降低。
 官网介绍：防止不同的线程同时获取相同的锁。
 重点：@synchronized 结构在工作时为传入的对象分配了一个递归锁。所谓递归锁是在被同一个线程重复后去时不会产生死锁。NSRecursiveLock（递归锁）类也是这样的，我们后面会有分析。
 特殊情况：
     1、你调用 sychronized 的每个对象，Objective-C runtime 都会为其分配一个递归锁并存储在哈希表中。
     2、如果在 sychronized 内部对象被释放或被设为 nil 看起来都 OK。不过这没在文档中说明，所以我不会再生产代码中依赖这条。
     3、注意不要向你的 sychronized block 传入 nil！这将会从代码中移走线程安全。你可以通过在 objc_sync_nil 上加断点来查看是否发生了这样的事情。
 
 使用场景：假设我们在用OC实现一个线程安全的队列，如下：
 */
- (void)synchronizedLock{
    /*
     NSMutableArray *_elements;
     _elements在任何情况下都只会在一个线程中运行
     */
    @synchronized(_elements){
        [_elements addObject:@"1"];
    };
}



/*
 三、递归锁NSRecursiveLock
 NSRecursiveLock递归锁可以被同一线程多次请求，但不会引起死锁。这主要是用在循环或者递归操作场景中。
 下面是递归锁的使用：
 */
- (void)useNSRecursiveLock{
    //如果使用_lock会招致死锁，因为被同一个线程多次调用。每次进入这个block时，都会去加一次锁，而从第二次开始，由于锁已经被使用了且没有解锁，所以它需要等待锁被解除，这样就导致了死锁，线程被阻塞住了。
//    _lock = [[NSLock alloc] init];
    NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //创建一个静态方法，block方法
        static void (^RecursiveMethod)(int);
        RecursiveMethod = ^(int value) {
            [lock lock];
            if (value > 0) {
                NSLog(@"value = %d", value);
                sleep(1);
                RecursiveMethod(value - 1);
            }
            [lock unlock];
        };
        RecursiveMethod(5);//方法内部判断来执行5次
    });
}

/*
 四、条件锁
 当我们在使用多线程的时候，只有一把会lock和unlock的锁就不能满足我们的需要了。因为普通的锁只关心锁与不锁，但是并不在乎什么时候才能开锁，而在处理资源共享场景的时候，多数情况下只有满足一定条件下才能打开这把锁：
 NSConditionLock实现步骤：
 NSConditionLock实现了NSLocking协议，一个线程会等待另一个线程unlock或者unlockWithCondition:之后再走lock或者lockWhenCondition:之后的代码。
 锁定和解锁的调用可以随意组合，也就是说 lock、lockWhenCondition:与unlock、unlockWithCondition: 是可以按照自己的需求随意组合的。
 划重点：
 1、只有 condition 参数与初始化时候的 condition 相等，lock 才能正确进行加锁操作。
 2、unlockWithCondition: 并不是当 condition 符合条件时才解锁，而是解锁之后，修改 condition 的值。
 */


/*
 在线程 1 解锁成功之后，线程 2 并没有加锁成功，而是继续等了 1 秒之后线程 3 加锁成功，这是因为线程 2 的加锁条件不满足，初始化时候的 condition 参数为 0，而线程 2
 加锁条件是 condition 为 1，所以线程 2 加锁失败。
 lockWhenCondition 与 lock 方法类似，加锁失败会阻塞线程，所以线程 2 会被阻塞着。
 tryLockWhenCondition: 方法就算条件不满足，也会返回 NO，不会阻塞当前线程。
 lockWhenCondition:beforeDate:方法会在约定的时间内一直等待 condition 变为 2，并阻塞当前线程，直到超时后返回 NO。
 
 */
- (void)nsconditionlock {
    NSConditionLock * cjlock = [[NSConditionLock alloc] initWithCondition:0];
    
    //1、线程 1 解锁成功
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [cjlock lock];
        NSLog(@"线程1加锁成功");
        sleep(1);//线程休眠一秒
        [cjlock unlock];
        NSLog(@"线程1解锁成功");
    });
    
    //2、初始化时候的 condition 参数为0，所以此处加锁失败，返回NO，此处线程阻塞。全部现成执行完毕后执行此处锁
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);//线程休眠一秒
        [cjlock lockWhenCondition:1];
        NSLog(@"线程2加锁成功");
        [cjlock unlock];
        NSLog(@"线程2解锁成功");
    });
    
    //3、tryLockWhenCondition尝试加锁  初始化时候的 condition 参数为0，所以此处加锁成功。方法就算条件不满足，也会返回 NO，不会阻塞当前线程。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        
        if ([cjlock tryLockWhenCondition:0]) {
            NSLog(@"线程3加锁成功");
            sleep(2);
            /*
             A：成功案例
             这里会先解锁当前的锁，之后修改condition的值为100.在下一个condition为100的线程中会加解锁成功，如果下个锁中的condition等待的值不是100，那么就会导致加锁失败。
             */
            [cjlock unlockWithCondition:100];
            NSLog(@"线程3解锁成功");
            
            /*
             B：失败案例
             [cjlock unlockWithCondition:4];
             NSLog(@"线程3仍然会解锁成功，之后修改condition的值为4");
             */
            
        } else {
            NSLog(@"线程3尝试加锁失败");
        }
    });
    
    //4、lockWhenCondition:beforeDate:方法会在约定的时间内一直等待 condition 变为 2，并阻塞当前线程，直到超时后返回 NO。
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([cjlock lockWhenCondition:100 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]]) {
            NSLog(@"线程100加锁成功");
            [cjlock unlockWithCondition:1];
            NSLog(@"线程100解锁成功");
        } else {
            NSLog(@"线程100尝试加锁失败");
        }
    });
}


/*
 五：NSCondition
 定义及使用：NSCondition 是一种特殊类型的锁，通过它可以实现不同线程的调度。A线程被某一个条件所阻塞，直到B线程满足该条件，从而发送信号给A线程使得A线程继续执行，例如：你可以开启一个线程下载图片，一个线程处理图片。这样的话，需要处理图片的线程由于没有图片会阻塞，当下载线程下载完成之后，则满足了需要处理图片的线程的需求，这样可以给定一个信号，让处理图片的线程恢复运行。
 重点：
 1、NSCondition 的对象实际上作为一个锁和一个线程检查器，锁上之后，其他线程也能继续上锁，之后根据条件决定是否继续运行线程，如果线程进入waiting状态，当其他线程中的该锁执行signal（信号）或者broadcast（广播）时，线程被唤醒，继续运行该线程之后的方法。。
 2、NSCondition 可以手动控制现成的挂起和唤醒，可以利用这个特性设置依赖。
 特别提醒：
 signal只是唤醒单个线程，broadcast唤醒所有的线程。
 */

- (void)nsCondition {
    NSCondition * cjcondition = [NSCondition new];
    /*
     在加上锁之后，调用条件对象的 wait 或 waitUntilDate: 方法来阻塞线程，直到条件对象发出唤醒信号或者超时之后，再进行之后的操作。
     */
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [cjcondition lock];
        NSLog(@"线程1线程加锁----NSTreat：%@",[NSThread currentThread]);
        [cjcondition wait];
        NSLog(@"线程1线程唤醒");
        [cjcondition unlock];
        NSLog(@"线程1线程解锁");
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [cjcondition lock];
        NSLog(@"线程2线程加锁----NSTreat：%@",[NSThread currentThread]);
        if ([cjcondition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]]) {
            NSLog(@"线程2线程唤醒");
            [cjcondition unlock];
            NSLog(@"线程2线程解锁");
        }
    });

    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        sleep(2);
        //一次只能唤醒一个线程，要调用多次才可以唤醒多个线程，如下调用两次，将休眠的两个线程解锁
        [cjcondition signal];
        [cjcondition signal];

        //一次性全部唤醒
        //[cjcondition broadcast];
    });
}

/*
 六：dispatch_semaphore信号量
 GCD的信号量机制实现锁，等待信号和发送信号。
 1、dispatch_semaphore 是 GCD 用来同步的一种方式，与他相关的只有三个函数，一个是创建信号量，一个是等待信号，一个是发送信号。
 2、dispatch_semaphore的机制就是当有多个线程进行访问的时候，只要有一个获得了信号，其他线程就必须等待该信号的释放。
 
 重点内容：
 1、dispatch_semaphore 和 NSCondition 类似，都是一种基于信号的同步方式，但 NSCondition 信号只能发送，不能保存（如果没有线程在等待，则发送的信号会失效）。而 dispatch_semaphore 能保存发送的信号。dispatch_semaphore 的核心是 dispatch_semaphore_t 类型的信号量。
 2、dispatch_semaphore_create(1) 方法可以创建一个 dispatch_semaphore_t （ 英  ['seməfɔː]）类型的信号量，设定信号量的初始值为 1。注意，这里的传入的参数必须大于或等于 0，否则 dispatch_semaphore_create 会返回 NULL。
 3、dispatch_semaphore_wait(semaphore, overTime); 方法会判断 semaphore 的信号值是否大于 0。大于 0 不会阻塞线程，消耗掉一个信号，执行后续任务。如果信号值为 0，该线程会和 NSCondition 一样直接进入 waiting状态，等待其他线程发送信号唤醒该线程执行后续任务，或者当 overTime 时限到了，也会执行后续任务。
 4、dispatch_semaphore_signal(semaphore); 发送信号，如果没有等待的线程接受信号，则使 signal 信号值加一（做到对信号的保存）。
 5、一个 dispatch_semaphore_wait(semaphore, overTime); 方法会去对应一个 dispatch_semaphore_signal(semaphore); 看起来像 NSLock 的 lock 和 unlock，其实可以这样理解，区别只在于有信号量这个参数，，lock unlock 只能同一时间，只能有一个线程访问被保护的临界区，而如果信号量参数初始值为 x，那么就会有 x 个线程可以同时访问被保护的临界区。
 */
- (void)useDispatch_semaphore {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    // overTime设置为6秒
    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC);
   
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_semaphore_wait(semaphore, overTime);
        NSLog(@"线程1开始");
        sleep(5);
        NSLog(@"线程1结束");
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        dispatch_semaphore_wait(semaphore, overTime);
        NSLog(@"线程2开始");
        dispatch_semaphore_signal(semaphore);
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        dispatch_semaphore_wait(semaphore, overTime);
        NSLog(@"线程3开始");
        dispatch_semaphore_signal(semaphore);
    });
}

/*
 七、OSSpinLock自旋锁
 首先导入：#import <libkern/OSAtomic.h>
 OSSpinLock 是一种自旋锁，和互斥锁类似，都是为了保证线程安全的锁。但是而这是不一样的：
 互斥锁：当一个线程获得此锁之后，其他线程再获取将会被阻塞，直到该锁被释放。
 自旋锁：当一个线程获得此锁之后，其他线程将会一直循环查看该锁是否被释放。锁比较适用于锁的持有者保存时间较短的情况下。
 OSSpinLock自旋锁只有加锁，尝试加锁和解锁三个方法。
 
 YY大神 @ibireme 的文章也有说这个自旋锁存在优先级反转问题，具体文章可以戳 不再安全的 OSSpinLock，而 OSSpinLock 在iOS 10.0中被 <os/lock.h> 中的 os_unfair_lock 取代。
 */
- (void)osspinlock {
    __block OSSpinLock theLock = OS_SPINLOCK_INIT;//在iOS10之后被ns_unfair_lock替换
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        NSLog(@"线程1开始");
        sleep(3);
        NSLog(@"线程1结束");
        OSSpinLockUnlock(&theLock);
        
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        OSSpinLockLock(&theLock);
        sleep(1);
        NSLog(@"线程2");
        OSSpinLockUnlock(&theLock);
        
    });
}

/*
 八、os_unfair_lock替换七的自旋锁
 由于OSSpinLock自旋锁自身不太安全，在iOS10之后，然后苹果使用os_unfair_lock替换OSSpinLock解决优先级反转的问题。
 其实每一种锁基本上都是加锁、等待、解锁的步骤，理解了这三个步骤就可以帮你快速的学会各种锁的用法。
常用的相关API：
 // 初始化
 os_unfair_lock_t unfairLock = &(OS_UNFAIR_LOCK_INIT);
 // 加锁
 os_unfair_lock_lock(unfairLock);
 // 尝试加锁
 BOOL b = os_unfair_lock_trylock(unfairLock);
 // 解锁
 os_unfair_lock_unlock(unfairLock);
 os_unfair_lock 用法和 OSSpinLock 基本一直，就不一一列出了。
 */

/*
 锁的总结：
 1、@synchronized 的效率最低，不过它的确用起来最方便，所以如果没什么性能瓶颈的话，可以选择使用 @synchronized。
 2、当性能要求较高时候，可以使用 pthread_mutex 或者 dispath_semaphore，由于 OSSpinLock 不能很好的保证线程安全，而在只有在 iOS10 中才有 os_unfair_lock ，所以，前两个是比较好的选择。既可以保证速度，又可以保证线程安全。
 3、对于 NSLock 及其子类，速度来说 NSLock < NSCondition < NSRecursiveLock < NSConditionLock 。
 */






@end
