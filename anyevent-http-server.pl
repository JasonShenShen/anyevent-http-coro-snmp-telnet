#!/usr/local/bin/perl

use FindBin;use lib "$FindBin::Bin/../blib/lib";
use AnyEvent;
use AnyEvent::HTTP::Server;
use EV;
use Data::Dumper;
use Getopt::Long;
use Parallel::ForkManager;

###usage
use constant USAGEMSG => <<USAGE; 
Usage: $0
    Options:
        -thread     thread number   the count of multithread
        -port       PORT            监听端口
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

##定义信号
$SIG{TERM}=$SIG{INT}=$SIG{KILL}=\&toexit;
my %childinfo = ();
my $fatherid = $$;
my $i = 0;
my $pm=new Parallel::ForkManager($thread); #并发thread
$pm->run_on_finish(
    sub { 
        my ($pid, $exit_code, $ident) = @_;
        #结束子进程
        delete $childinfo{$pid};
        print "** $ident just got out of the pool with PID $pid and exit code: $exit_code\n";
    }
);

$pm->run_on_start(
    sub { 
        my ($pid,$ident)=@_;
        #开启子进程
        $childinfo{$pid} =1;
        print "** $ident started, pid: $pid\n";
    }
);
while(1){
    $i++;
    my $pid = $pm->start($i) and next;
    warn "[$fatherid]: $i Start...\n";
    $ret = &StartAccept($i);
    $pm->finish($i);
}
$pm->wait_all_children;
exit(0);

sub route(){
    my $request = shift;
    my $status  = 200;
    #my $message = $request[8]->('content-message');
    #print Dumper($request);
    print "url:".$request->path()."\n";
    my $message = $request->contentmessage();
    print "message:$message\n";
    my $workid = $request->param('work');
    my $content = "<h1>work:$workid</h1>";
    print "para:$workid\n";
    #Content-Type: text/htm
    #Connection: close
    #my $headers = { 'content-type' => 'text/html','connection' => 'close' };
    my $headers = { 'content-type' => 'text/html'};
    $request->reply($status, $content, headers => $headers);
}

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
        $s->graceful(sub {
            warn "Server stopped";
            EV::unloop;
            exit 1;
        });
    };
    AE::signal TERM => sub {
        warn "Stopping server";
        $s->graceful(sub {
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