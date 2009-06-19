package Cache::Migrate;

use strict;
use warnings;
use Carp;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(debug));

our $VERSION = "0.01";

sub new {
    my $class = shift;
    my @opt = @_;
    my $self;
    if (exists $opt[0]->{caches}) {
        $self = {
            debug => $opt[0]->{debug} || 0,
            _cache => $opt[0]->{caches}
        };
    } else {
        $self = {
            _cache => \@opt
        };
    }
    bless $self, $class;
}

# delegate setting
# read  request: get,gets
# write request: set,add,replace,cas,incr,decr,append,prepend,delete

BEGIN {
    my @read = qw(get gets);
    my @read_multi = map { $_ ."_multi" } @read; 
    my @write = qw(set add replace cas incr decr append prepend delete);
    my @write_multi = map { $_ ."_multi" } @write; 
    
    for my $method_name (@read, @read_multi) {
        eval sprintf(<<'__SUB__', $method_name, $method_name);
        sub %s {
            my $self = shift;
            $self->_delegate_read("%s", @_);
        }
__SUB__
        warn $@ if $@;
    }

    for my $method_name (@write, @write_multi) {
        eval sprintf(<<'__SUB__', $method_name, $method_name);
        sub %s {
            my $self = shift;
            $self->_delegate_write("%s", @_);
        }
__SUB__
        warn $@ if $@;
    }
}

# select usable cache engine
sub _select_usable_cache {
    my $self = shift;
    return map { $_->{cache} } grep {
        !exists $_->{expires_on} || time < $_->{expires_on} 
    } @{$self->{_cache}};
}

# read from first usable cache object
sub _delegate_read {
    my $self = shift;
    my ($method, @args) = @_;
    my ($cache) = $self->_select_usable_cache;
    if (!$cache) {
        carp "can't find usable cache!" if $self->debug;
        return;
    }
    $cache->$method(@args);
}

# write for all usable cache object
sub _delegate_write {
    my $self = shift;
    my ($method, @args) = @_;
    my @all = $self->_select_usable_cache;
    my @result;
    my $result;
    if (!@all) {
        carp "can't find usable cache!" if $self->debug;
        return;
    }
    warn sprintf("%d usable cache object(s)", scalar @all) if $self->debug;
    for my $cache (@all) {
        if (wantarray) {
            @result = $cache->$method(@args);
        } else {
            $result = $cache->$method(@args);
        }
    }
    return wantarray ? @result : $result;
}

1;

__END__

=pod

=head1 NAME

Cache::Migrate - help your cache engine upgrade 

=head1 SYNOPSIS

  use Cache::Migrate;
  use Date::Parse;
  use Cache::Memcached::Fast;
  
  $old_cache = Cache::Memcached::Fast->new({servers => ["127.0.0.1:11211"] });
  $new_cache = Cache::Memcached::Fast->new({servers => ["127.0.0.1:11212"] });
  $cache = Cache::Migrate->new(
     { cache => $old_cache, expires_on => str2time("2009/05/15 00:00:00") },
     { cache => $new_cache },
  );
   or 
  $cache = Cache::Migrate->new({
     debug => 1,
     caches => [
         { cache => $old_cache, expires_on => str2time("2009/05/15 00:00:00") },
         { cache => $new_cache },
     ],
  });

  # update request to $new_cache and $old_cache
  $cache->set("key", $value);

  # read request to $old_cache before expire. use $new_cache if $old_cache is expired
  $cache->get("key");
  
=head1 DESCRIPTION

This module help your cache system upgrade without lost your cache objects. 

=head1 AUTHOR

mala E<lt>cpan@ma.laE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


