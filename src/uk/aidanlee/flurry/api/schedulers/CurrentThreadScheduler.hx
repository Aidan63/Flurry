package uk.aidanlee.flurry.api.schedulers;

import haxe.Timer;
import rx.Subscription;
import rx.schedulers.Base;
import rx.schedulers.MakeScheduler;
import rx.disposables.ISubscription;

class CurrentThreadScheduler extends MakeScheduler
{
    public static final current = new CurrentThreadScheduler();

    public function new()
    {
        super(new CurrentThreadBase());
    }
}

private class CurrentThreadBase implements Base
{
    public function new()
    {
        //
    }

    public function now()
    {
        return Timer.stamp();
    }

    public function schedule_absolute(_dueTime : Null<Float>, _action : () -> Void) : ISubscription
    {
        _action();

        return Subscription.empty();
    }
}