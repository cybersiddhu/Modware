package Modware::Role::Command::WithEmail;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Email::Sender::Simple qw/sendmail/;
use Email::Simple;
use Email::Sender::Transport::SMTP;

# Module implementation
#

has [qw/host from to subject/] => ( is => 'rw', isa => 'Str' );

sub robot_email {
    my ( $self, $msg ) = @_;
    my $trans
        = Email::Sender::Transport::SMTP->new( { host => $self->host } );
    my $email = Email::Simple->create(
        header => [
            From    => $self->from,
            To      => $self->to,
            Subject => $self->subject
        ],
        body => $msg
    );

    sendmail( $email, { transport => $trans } );
}

1;    # Magic true value required at end of module

