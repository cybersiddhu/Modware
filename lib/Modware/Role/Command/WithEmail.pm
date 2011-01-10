package Modware::Role::Command::WithEmail;

# Other modules:
use namespace::autoclean;
use Moose::Role;
use Email::Sender::Simple qw/sendmail/;
use Email::Simple;
use Email::Sender::Transport::SMTP;
use Moose::Util::TypeConstraints;
use Email::Valid;

# Module implementation
#


subtype 'Email' => as 'Str' => where { Email::Valid->address($_) };

has 'host' => (
    is            => 'rw',
    isa           => 'Str',
    required      => 1,
    documentation => 'SMTP host for sending e-mail'
);

has 'to' => (
    is  => 'rw',
    isa => 'Email',
    default => 'dictybase@northwestern.edu',
    documentation =>
        'e-mail parameter,  default is dictybase@northwestern.edu'
);

has 'from' => (
    is  => 'rw',
    isa => 'Email',
    default => 'dictybase@northwestern.edu',
    documentation =>
        'e-mail parameter,  default is dictybase@northwestern.edu'
);

has 'subject' => (
    is            => 'rw',
    isa           => 'Str',
    default       => 'e-mail from chicken robot',
    documentation => 'e-mail parameter,  default is *email from chicken robot*'
);

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

