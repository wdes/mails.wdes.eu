<?php
declare(strict_types = 1);
namespace Wdes\Mails\Infrastructure\tests;

require_once '/composer/autoload.php';

use PHPUnit\Framework\TestCase;
use Webklex\PHPIMAP\ClientManager;
use Webklex\PHPIMAP\Client;
use function sprintf;
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
use stdClass;

class SendAndReceiveTest extends TestCase
{
    public const MAIL_HOST = 'emails.mail-server.intranet';
    public const USERS = [
        'john' => [
            'username' => 'john@williamdes.corp',
            'password' => 'JohnPassWord!645987zefdm',
            'aliases' => [
                'john.pondu@williamdes.corp',
            ],
        ],
        'cyrielle' => [
            'username' => 'cyrielle@williamdes.corp',
            'password' => 'PassCyrielle!ILoveDogs',
            'aliases' => [
                'cyrielle.pondu@williamdes.corp',
                'contact@desportes.corp',
            ],
        ],
    ];

    private Client|null $mailboxClient = null;

    public static function dataProviderEmails(): array
    {
        $data = [];
        foreach (array_keys(self::USERS) as $userName) {
            $data[] = [$userName];
        }
        return $data;
    }

    public function tearDown(): void
    {
        if ($this->mailboxClient !== null) {
            $this->mailboxClient->disconnect();
        }
    }

    private function connectToMailbox(string $userName): void
    {
        if ($this->mailboxClient !== null) {
            $this->mailboxClient->disconnect();
        }

        $cm = new ClientManager([]);
        $this->mailboxClient = $cm->make([
            'host'           => self::MAIL_HOST,
            'port'           => 993,
            'encryption'     => 'ssl',
            'validate_cert'  => false,
            'protocol'       => 'imap',
            'username'       => self::USERS[$userName]['username'],
            'password'       => self::USERS[$userName]['password'],
        ]);

        //Connect to the IMAP Server
        $this->mailboxClient->connect();

        $this->assertTrue($this->mailboxClient->isConnected());
        sleep(2);
    }

    /**
     * @dataProvider dataProviderEmails
     */
    public function testImapConnectEmailsAndClean(string $userName): void
    {
        $this->connectToMailbox($userName);
        $this->deleteAllMails();
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmailsAndClean
     */
    public function testImapConnectEmails(string $userName): void
    {
        $this->connectToMailbox($userName);

        $this->deleteAllMails();

        $folders = $this->mailboxClient->getFolders()->map(fn ($f) => $f->name)->toArray();

        natsort($folders);
        $folders = array_values($folders);
        $this->assertSame([
            $mailbox . 'Drafts',
            $mailbox . 'INBOX',
            $mailbox . 'Junk',
            $mailbox . 'Sent',
            $mailbox . 'Trash',
        ], $folders);

        $folder = $this->mailboxClient->getFolderByPath('INBOX');
        $this->assertSame(0, $folder->messages()->count());
    }

    private function getMailById(string $userName, string $messageId): ?stdClass
    {
        $this->connectToMailbox($userName);

        $folder = $this->mailboxClient->getFolderByPath('INBOX');
        $msgs = $folder->overview('1:*');

        foreach ($msgs as $msg) {
            var_dump($msg, $messageId);
            if ('<' . $msg['message_id'] . '>' === $messageId) {
                return (object) [
                    'headers' => (object) [
                        'subject' => $msg['subject'],
                    ],
                ];
            }
        }

        return null;
    }

    private function deleteAllMails(): void
    {
        $folder = $this->mailboxClient->getFolderByPath('INBOX');
        $messages = $folder->messages()->all()->get();

        if ($messages->count() > 0) {
            foreach($messages as $message){
                $message->delete(true);
            }
        }
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmails
     */
    public function testImapConnectSendEmailsTls(string $userName): void
    {
        [$sent, $messageId] = $this->sendMail(
            true,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            self::USERS[$userName]['username'],
            self::USERS[$userName]['username'],
            'Mail to myself using TLS',
            'Just a mail to myself. Sent via TLS'
        );
        $this->assertTrue($sent, 'A TLS mail');
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNotNull($mailFound, 'Mail should be found');
        $this->assertSame('Mail to myself using TLS', $mailFound->headers->subject);
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmails
     */
    public function testImapConnectSendEmailsUnsecure(string $userName): void
    {
        $this->expectException(Exception::class);
        $this->expectExceptionMessage('SMTP Error: Could not authenticate');

        $this->sendMail(
            null,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            self::USERS[$userName]['username'],
            self::USERS[$userName]['username'],
            'Mail to myself using RAW:25',
            'Just a mail to myself. Sent via RAW:25',
            true
        );
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmails
     */
    public function testImapConnectSendEmailsSmtps(string $userName): void
    {
        [$sent, $messageId] = $this->sendMail(
            false,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            self::USERS[$userName]['username'],
            self::USERS[$userName]['username'],
            'Mail to myself using SMTPS',
            'Just a mail to myself. Sent via SMTPS'
        );
        $this->assertTrue($sent, 'A non TLS mail');
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNotNull($mailFound, 'Mail should be found');
        $this->assertSame('Mail to myself using SMTPS', $mailFound->headers->subject);
    }

    /**
     * This test sends an email from the user primary email to the user alias
     * @depends testImapConnectEmails
     */
    public function testExternalDomainSendFromInternal(): void
    {
        $userName = 'cyrielle';

        [$sent, $messageId] = $this->sendMail(
            true,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            self::USERS[$userName]['username'],
            self::USERS[$userName]['aliases'][1],
            'Mail to myself using TLS',
            'Just a mail to myself. Sent via TLS'
        );
        $this->assertTrue($sent, 'A TLS mail');
        sleep(60);
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNotNull($mailFound, 'Mail should be found');
        $this->assertSame('Mail to myself using TLS', $mailFound->headers->subject);
    }

    /**
     * This test sends an email from the user alias to the user alias
     * @depends testImapConnectEmails
     */
    public function testExternalDomainSendFromInternalToSendExternalInternal(): void
    {
        $userName = 'cyrielle';

        [$sent, $messageId] = $this->sendMail(
            true,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            self::USERS[$userName]['aliases'][1],
            self::USERS[$userName]['aliases'][1],
            'Mail to myself using TLS',
            'Just a mail to myself. Sent via TLS'
        );
        $this->assertTrue($sent, 'A TLS mail');
        sleep(15);
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNotNull($mailFound, 'Mail should be found');
        $this->assertSame('Mail to myself using TLS', $mailFound->headers->subject);
    }

    /**
     * This test sending an email for a domain that denies it in SPF is rejected
     * @depends testImapConnectEmails
     */
    public function testSendingAnEmailRelayAccessDenied(): void
    {
        $this->markTestIncomplete('To be re-done');
        // In this scenario there is no SMTP server to login, so we send directly to destination
        // But since the destination does not know the destination email: sesame+relay-access-test@aladin.private
        // It says that relay sending is denied
        [,, $e, $errorInfo] = $this->sendNoSmtpMail(
            true,
            'john@williamdes.corp',
            'sesame+relay-access-test@aladin.private',
            'Relay access denied test',
            'Just a test email.'
        );
        $this->assertSame('Could not instantiate mail function.', $errorInfo);
        $this->assertSame('Could not instantiate mail function.', $e->getMessage());
    }

    /**
     * This test sending an email from an address the user does not own
     * @depends testImapConnectEmails
     */
    public function testSendingAnEmailFromAnEmailThatIsNotOwned(): void
    {
        $userName = 'cyrielle';

        $this->expectException(Exception::class);
        $this->expectExceptionMessage(
            'SMTP Error: The following recipients failed: contact@desportes.corp: <sesame+relay-access-test@aladin.private>: Sender address rejected: not owned by user cyrielle@williamdes.corp'
        );
        [$sent, $messageId] = $this->sendMail(
            true,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            'sesame+relay-access-test@aladin.private',// from
            self::USERS[$userName]['aliases'][1],// to
            'Mail to myself using TLS',
            'Just a mail to myself. Sent via TLS',
            true
        );
    }

    /**
     * This test sending an email from an address the user does not own but is owned by an internal user
     * @depends testImapConnectEmails
     */
    public function testSendingAnEmailFromAnEmailThatIsNotOwnedAndInternal(): void
    {
        $userName = 'cyrielle';

        $this->expectException(Exception::class);
        $this->expectExceptionMessage(
            'SMTP Error: The following recipients failed: contact@desportes.corp: <john.pondu@williamdes.corp>: Sender address rejected: not owned by user cyrielle@williamdes.corp'
        );
        [$sent, $messageId] = $this->sendMail(
            true,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password'],
            self::USERS['john']['aliases'][0],// from
            self::USERS[$userName]['aliases'][1],// to
            'Mail to myself using TLS',
            'Just a mail to myself. Sent via TLS',
            true
        );
    }

    /**
     * This test sending an email for a domain that denies it in SPF is rejected
     * @depends testImapConnectEmails
     */
    public function testSendingAnEmailFromSPFNotAllowedIsDenied(): void
    {
        $this->markTestIncomplete('To be re-done');
        // In this scenario there is no SMTP server to login, so we send directly to destination
        // The server knows the recipient email: john@williamdes.corp
        // It checks SPF on williamdes.corp
        [,, $e, $errorInfo] = $this->sendNoSmtpMail(
            true,
            'contact+parked-domain@cream.home',
            'contact+parked-domain@cream.home',
            'SPF test',
            'Just a test email.'
        );
        $this->assertSame('Could not instantiate mail function.', $errorInfo);
        $this->assertSame('Could not instantiate mail function.', $e->getMessage());
    }

    /**
     * This test sends an email from an external server to an internal email but not the primary domain
     * @depends testImapConnectEmails
     */
    public function testFromExternalToInternalAlias(): void
    {
        $userName = 'cyrielle';
        [$sent, $messageId] = $this->sendNoSmtpMail(
            true,
            'sesame@aladin.private',
            self::USERS[$userName]['aliases'][1],
            'Mail to myself, postgreydelay',
            'Just a mail to myself. postgreydelay.'
        );
        $this->assertTrue($sent, 'A TLS mail');
        sleep(15);
        $mailFound = $this->getMailById($userName, $messageId);
        if ($mailFound) {
            // This will mark this test as risky, the mail should be greylisted
            // Maybe this is a test re-run
            return;
        }
        sleep(10);// wait for POSTGREY_DELAY + some time
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNull($mailFound, 'The mail should not be found !');
        sleep(10);// Sleep again
        [$sent, $messageId] = $this->sendNoSmtpMail(
            true,
            'sesame@aladin.private',
            self::USERS[$userName]['aliases'][1],
            'Mail to myself passing postgrey',
            'Just a mail to myself. postgrey pass.'
        );
        sleep(10);// Sleep again and hope
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNotNull($mailFound, 'The mail should be found !');
        $this->assertSame('Mail to myself passing postgrey', $mailFound->headers->subject);
        $this->assertTrue($sent, 'A TLS mail');
    }

    /**
     * @param bool|null $useTLS
     */
    private function sendMail(
        $useTLS,
        string $username, string $password,
        string $from, string $to,
        string $object, string $body,
        bool $throwError = false
    ): array {
        $mail = new PHPMailer(true);

        try {
            //$mail->SMTPDebug = \PHPMailer\PHPMailer\SMTP::DEBUG_SERVER;
            $mail->isSMTP();
            $mail->Host       = self::MAIL_HOST;
            $mail->SMTPAuth   = true;
            $mail->Username   = $username;
            $mail->Password   = $password;
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
            $mail->Port       = 465;
            if ($useTLS === true) {
                $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
                $mail->Port       = 587;
            }
            // Check it is in sync with the cert in the acme.sh dir
            $fingerprint = file_get_contents('/etc/ssl/emails.mail-server.intranet.cer');
            $this->assertNotFalse($fingerprint, 'Cert should be found');
            $mail->SMTPOptions = [
                'ssl' => [
                    'verify_peer' => false,
                    'verify_peer_name' => true,
                    'peer_fingerprint'  => openssl_x509_fingerprint($fingerprint),
                ]
            ];

            if ($useTLS === null) {
                $mail->Port        = 25;
                $mail->SMTPOptions = [];
                $mail->SMTPAutoTLS = false;
                $mail->SMTPSecure  = false;
            }

            $mail->setFrom($from);
            $mail->addAddress($to);
            $mail->Subject = $object;
            $mail->Body    = $body;

            return [$mail->send(), $mail->GetLastMessageID()];
        } catch (Exception $e) {
            if ($throwError) {
                throw $e;
            }
            $this->fail('Message could not be sent. Mailer Error: ' . $mail->ErrorInfo);
        }
    }

    private function sendNoSmtpMail(
        bool $skipFailure,
        string $from, string $to,
        string $object, string $body): array
    {
        $mail = new PHPMailer(true);

        try {
            $mail->setFrom($from);
            $mail->addAddress($to);
            $mail->Subject = $object;
            $mail->Body    = $body;
            //$mail->SMTPDebug = 3;
            // $mail->Debugoutput = function($str, $level) {fwrite(STDERR, "debug level $level; message: $str" . PHP_EOL);};
            $mailSent = $mail->send();
            return [$mailSent, $mail->GetLastMessageID()];
        } catch (Exception $e) {
            if (! $skipFailure) {
                $this->fail('Message could not be sent. Mailer Error: ' . $mail->ErrorInfo);
            }
            return [null, $mail->GetLastMessageID(), $e, $mail->ErrorInfo];
        }
    }
}
