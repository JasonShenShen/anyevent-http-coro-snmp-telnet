#!/usr/local/bin/perl
#use ae::httpserver workers to recevice req , create coro-telnet to device and response to client
use strict;
use FindBin;use lib "$FindBin::Bin/../blib/lib";
use AnyEvent::HTTP::Server;
use EV;
use Coro;
use AnyEvent;
use AnyEvent::SNMP;
use Net::SNMP;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;
use Coro::Handle;
use AnyEvent::Socket;
use CoroTelnet;
use JSON qw/encode_json decode_json to_json/;

###usage
use constant USAGEMSG => <<USAGE; 
Usage: $0
    Options:
        -thread     thread number   the count of multithread
        -port       PORT            listen port
USAGE

GetOptions(
    'p|port=s'   => \( my $port = 19999 ),
    't|thread=s'   => \( my $thread = 1 )
);


$| = 1;
my $server = AnyEvent::HTTP::Server->new(
     host => "0.0.0.0",
     port => $port,
     cb => \&{route},
);
$server->listen;

$SIG{TERM}=$SIG{INT}=$SIG{KILL}=\&toexit;
our %childinfo = ();
our %httpsession=();
my $fatherid = $$;
my $i = 0;
my $pm=new Parallel::ForkManager($thread);

=pod
/**
 * [code workers moni]
 * @type {[type]}
 */
=cut
$pm->run_on_finish(
    sub { 
        my ($pid, $exit_code, $ident) = @_;
        delete $childinfo{$pid};
        delete $httpsession{$pid};
        print "** $ident just got out of the pool with PID $pid and exit code: $exit_code\n";
    }
);

=pod
/**
 * [code workers moni]
 * @type {[type]}
 */
=cut
$pm->run_on_start(
    sub { 
        my ($pid,$ident)=@_;
        $childinfo{$pid} =1;
        print "** $ident started, pid: $pid\n";
    }
);

=pod
/**
 * [while create workers]
 * @AuthorHTL zhangqi
 * @DateTime  2017-03-14T13:21:42+0800
 * @param     {[type]}                 1 [description]
 * @return    {[type]}                   [description]
 */
=cut
while(1){
    $i++;
    my $pid = $pm->start($i) and next;
    warn "[$fatherid]: $i Start...\n";
    my $ret = &StartAccept($i);
    $pm->finish($i);
}
$pm->wait_all_children;
exit(0);

=pod
/**
 * [route create coro and accept method]
 * @AuthorHTL zhangqi
 * @DateTime  2017-03-13T20:06:39+0800
 * @return    {[type]}                 [description]
 */
=cut
sub route(){
    my $request = shift;
    #my $message = $request[8]->('content-message');
    #print Dumper($request);
    #print "url:".$request->path()."\n";
    my $message = $request->contentmessage();
    #print "message:$message\n";
    # message:{
    #     "hostip": "192.168.6.87"
    # }
    my $result_json;
    if($message ne ''){
        eval {
            $result_json = decode_json($message);
        };
        if ($@) {
            # handle failure...
        }
    }
    # $VAR1 = {
    #       'hostip' => '192.168.6.87'
    #     };
    my $headers = { 'content-type' => 'text/html','connection' => 'close'};
    my $hostip = $result_json->{hostip};
    my $items = $result_json->{items};
    print Dumper(\%httpsession);
    #para error response 400
    if($hostip eq ''
        || $items eq ''){
        $result_json->{'form'} = "empty task";
        my $ret = to_json($result_json,{utf8 => 1, pretty => 1});
        $request->reply(400, $ret, headers => $headers);
    }
    else{
        my @iplists = split /,/, $hostip;
        my @coro;
        while($#iplists >= 0) {
            my $ip = shift @iplists;
            push @coro,async {
                my $ret;
                $httpsession{$$}{$ip} = 1;
                #create sess
                $Coro::current->{desc} = $ip;
                my $coro_tel_sess = CoroTelnet->new(
                    PeerAddr => $ip,
                    PeerPort => 23,
                    timeout=>5,
                );
                return -1 if($coro_tel_sess eq '');
        
                #WaitFor
                my ($ret,$match) = $coro_tel_sess->WaitFor("Username:");
                #print Coro::current->{desc}." begin**\n".$ret.$match."\n";
                
                $coro_tel_sess->PrintMsg("aaa");
                ($ret,$match) = $coro_tel_sess->WaitFor(":");
                $coro_tel_sess->PrintMsg("aaa");
                
                ($ret,$match) = $coro_tel_sess->WaitFor('#');
                $coro_tel_sess->PrintMsg($items);
                ($ret,$match) = $coro_tel_sess->WaitFor('#');
                print "ret:$ret\n";
                return $ret;
            };
        }
        # coro join and put channel
        my $queue_join = 0;
        my $indexcount = 0;
        my $ret;
        async_pool {
            #Coro::AnyEvent::sleep 1;
            foreach (@coro){
                $ret .= $_->join;
                # multi device 分割 number
                $ret .= "\n##################################".$indexcount."##################################\n";
                $indexcount++;
            }
            $queue_join++;
        };
        # create timer to get channel
        my $cv = AnyEvent->condvar( cb => sub {
            print "调用结束\n";
        });
        $cv->begin;
        my $timeout_count = 40;
        my $w; $w = AnyEvent->timer(
                after       => 2, 
                interval => 0.5,
                cb => sub {
                    if ( $queue_join > 0) {
                        #$result_json->{'form'} = $ret;
                        eval{
                           #$ret = to_json($result_json,{utf8 => 1, pretty => 1});
                        };
                        $request->reply(200, $ret, headers => $headers);
                        undef $w;
                        $cv->end;
                        #undef $cv;
                    }
                    elsif ($timeout_count == 0){
                        $request->reply(400, "TIme out", headers => $headers);
                        undef $w;
                        $cv->end;
                        #undef $cv;
                    }
                    $timeout_count--;
                }
        );
        $cv->recv; #阻塞会报异常但不影响整体功能，是否有内存回收问题
    }
}

=pod
/**
 * [StartAccept register service]
 * @AuthorHTL zhangqi
 * @DateTime  2017-03-13T20:07:43+0800
 */
=cut
sub StartAccept(){
    my ($ident) = @_;
    AE::signal INT => sub {
        warn "Stopping server";
        $server->graceful(sub {
            warn "Server stopped";
            EV::unloop;
            exit 1;
        });
    };
    AE::signal KILL => sub {
        warn "Stopping server";
        $server->graceful(sub {
            warn "Server stopped";
            EV::unloop;
            exit 1;
        });
    };
    AE::signal TERM => sub {
        warn "Stopping server";
        $server->graceful(sub {
            warn "Server stopped";
            EV::unloop;
            exit 1;
        });
    };
    $server->accept;
    EV::loop;
}

sub Usage(){
    print USAGEMSG;
    exit(0);
}

=pod
/**
 * [toexit suporvisor workers]
 * @AuthorHTL
 * @DateTime  2017-03-14T13:24:24+0800
 * @return    {[type]}                 [description]
 */
=cut
sub toexit(){
    my $signame = shift;
    if($fatherid == $$){
        foreach my $pid (keys %childinfo){
            print "send me to die! I will die all service $pid\n";
            `kill $pid`;
        }
    }
    exit(0);
}

__END__

=head1 give demo reply path para and post contentmessage
sub simple(){
    my $request = shift;
    my $status  = 200;
    my $message = $request->contentmessage();
    print "message:$message\n";
    my $workid = $request->param('work');
    my $content = "<h1>work:$workid</h1>";
    my $headers = { 'content-type' => 'text/html','connection' => 'close' };
    #my $headers = { 'content-type' => 'text/html'};
    $request->reply($status, $content, headers => $headers);
}