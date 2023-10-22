<?php
declare(strict_types = 1);
namespace Datacenters\Infrastructure\tests;

require_once '/composer/autoload.php';

use PHPUnit\Framework\TestCase;
use function imap2_open;
use function sprintf;
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
use stdClass;

class SendAndReceiveTest extends TestCase
{
    public const MAIL_HOST = 'mail-server.mail.williamdes.eu.org';
    public const USERS = [
        'john' => [
            'username' => 'john@mail.williamdes.eu.org',
            'password' => 'JohnPassWord!645987zefdm',
            'aliases' => [
                'john.pondu@mail.williamdes.eu.org',
            ],
        ],
        'cyrielle' => [
            'username' => 'cyrielle@mail.williamdes.eu.org',
            'password' => 'PassCyrielle!ILoveDogs',
            'aliases' => [
                'cyrielle.pondu@mail.williamdes.eu.org',
                'contact@another-domain.intranet',
            ],
        ],
    ];

    public static function dataProviderEmails(): array
    {
        $data = [];
        foreach (array_keys(self::USERS) as $userName) {
            $data[] = [$userName];
        }
        return $data;
    }

    /**
     * @dataProvider dataProviderEmails
     */
    public function testImapConnectEmailsAndClean(string $userName): void
    {
        $mailbox = sprintf(
            '{%s:993/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap2_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $headers = imap2_check($mbox);
        if ($headers->Nmsgs > 0) {
            $this->deleteAllMails($mbox, $userName);
        }

        $this->assertTrue(imap2_close($mbox));
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmailsAndClean
     */
    public function testImapConnectEmails(string $userName): void
    {
        $mailbox = sprintf(
            '{%s:993/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap2_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $headers = imap2_check($mbox);
        if ($headers->Nmsgs > 0) {
            $this->deleteAllMails($userName);
            sleep(2);
        }

        $folders = imap2_listmailbox($mbox, $mailbox, '*');

        if ($folders === false) {
            $this->fail('Folder listing failed.');
        }

        natsort($folders);
        $folders = array_values($folders);
        $this->assertSame([
            $mailbox . 'Drafts',
            $mailbox . 'INBOX',
            $mailbox . 'Junk',
            $mailbox . 'Sent',
            $mailbox . 'Trash',
        ], $folders);

        $headers = imap2_headers($mbox);

        if ($headers === false) {
            $this->fail('Headers listing failed.');
        }

        $this->assertSame([], $headers);

        imap2_close($mbox);
    }

    private function getMailById(string $userName, string $messageId): ?stdClass
    {
        $mailbox = sprintf(
            '{%s:993/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap2_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $msgs = imap2_sort($mbox, SORTDATE, true, SE_UID);
        $foundMessage = null;
        foreach ($msgs as $msguid) {
            $msgno = imap2_msgno($mbox, $msguid);
            $headers = imap2_headerinfo($mbox, $msgno);
            $structure = imap2_fetchstructure($mbox, $msguid, FT_UID);
            if ($headers->message_id === $messageId) {
                $foundMessage = (object) [
                    'headers' => $headers,
                    'structure' => $structure,
                ];
                break;
            }
        }

        imap2_close($mbox);
        return $foundMessage;
    }

    private function deleteAllMails($mbox, string $userName): void
    {
        imap2_delete($mbox, '1:*');
        imap2_expunge($mbox);
    }

    private function deleteMailById(string $userName, string $msgNumber): bool
    {
        $mailbox = sprintf(
            '{%s:993/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap2_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $del = imap2_delete($mbox, $msgNumber);

        imap2_expunge($mbox);

        imap2_close($mbox);
        return $del;
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
        sleep(3);
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
        sleep(10);
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
        sleep(10);
        $this->assertTrue($sent, 'A TLS mail');
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
        sleep(2);
        $this->assertTrue($sent, 'A TLS mail');
        $mailFound = $this->getMailById($userName, $messageId);
        $this->assertNotNull($mailFound, 'Mail should be found');
        $this->assertSame('Mail to myself using TLS', $mailFound->headers->subject);
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
            'contact@external-domain.org',
            self::USERS[$userName]['aliases'][1],
            'Mail to myself, postgreydelay',
            'Just a mail to myself. postgreydelay.'
        );
        sleep(2);
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
            'contact@external-domain.org',
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
            $fingerprint = file_get_contents('/etc/ssl/mail.williamdes.eu.org.cer');
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
            return [$mail->send(), $mail->GetLastMessageID()];
        } catch (Exception $e) {
            if (! $skipFailure) {
                $this->fail('Message could not be sent. Mailer Error: ' . $mail->ErrorInfo);
            }
            return [null, $mail->GetLastMessageID()];
        }
    }
}
