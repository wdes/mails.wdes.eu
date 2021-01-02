<?php
declare(strict_types = 1);
namespace Desportes\Infrastructure\tests;

require_once '/composer/autoload.php';

use PHPUnit\Framework\TestCase;
use function imap_open;
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
                'contact@another-domain.com',
            ],
        ],
    ];

    public function dataProviderEmails(): array
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
            '{%s:993/imap4/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $headers = imap_check($mbox);
        if ($headers->Nmsgs > 0) {
            $this->deleteAllMails($mbox, $userName);
        }

        $this->assertTrue(imap_close($mbox));
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmailsAndClean
     */
    public function testImapConnectEmails(string $userName): void
    {
        $mailbox = sprintf(
            '{%s:993/imap4/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $headers = imap_check($mbox);
        if ($headers->Nmsgs > 0) {
            $this->deleteAllMails($userName);
            sleep(2);
        }

        $folders = imap_listmailbox($mbox, $mailbox, '*');

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

        $headers = imap_headers($mbox);

        if ($headers === false) {
            $this->fail('Headers listing failed.');
        }

        $this->assertSame([], $headers);

        imap_close($mbox);
    }

    private function getMailById(string $userName, string $messageId): ?stdClass
    {
        $mailbox = sprintf(
            '{%s:993/imap4/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $msgs = imap_sort($mbox, SORTDATE, 1, SE_UID);
        $foundMessage = null;
        foreach ($msgs as $msguid) {
            $msgno = imap_msgno($mbox, $msguid);
            $headers = imap_headerinfo($mbox, $msgno);
            $structure = imap_fetchstructure($mbox, $msguid, FT_UID);
            if ($headers->message_id === $messageId) {
                $foundMessage = (object) [
                    'headers' => $headers,
                    'structure' => $structure,
                ];
                break;
            }
        }

        imap_close($mbox);
        return $foundMessage;
    }

    private function deleteAllMails($mbox, string $userName): void
    {
        imap_delete($mbox, '1:*');
        imap_expunge($mbox);
    }

    private function deleteMailById(string $userName, string $msgNumber): bool
    {
        $mailbox = sprintf(
            '{%s:993/imap4/ssl/novalidate-cert}',
            self::MAIL_HOST
        );
        $mbox = imap_open(
            $mailbox,
            self::USERS[$userName]['username'],
            self::USERS[$userName]['password']
        );
        if ($mbox === false) {
            $this->fail('The mailbox could not be opened.');
        }

        $del = imap_delete($mbox, $msgNumber);

        imap_expunge($mbox);

        imap_close($mbox);
        return $del;
    }

    /**
     * @dataProvider dataProviderEmails
     * @depends testImapConnectEmails
     */
    public function testImapConnectSendEmails(string $userName): void
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
        sleep(2);
        $this->assertSame('Mail to myself using TLS', $this->getMailById($userName, $messageId)->headers->subject);
        $this->assertTrue($sent, 'A TLS mail');

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
        sleep(2);
        $mailFound = $this->getMailById($userName, $messageId);

        $this->assertSame('Mail to myself using TLS', $mailFound->headers->subject);
        $this->assertTrue($sent, 'A TLS mail');
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
        $mailFound = $this->getMailById($userName, $messageId);

        $this->assertSame('Mail to myself using TLS', $mailFound->headers->subject);
        $this->assertTrue($sent, 'A TLS mail');
    }

    private function sendMail(
        bool $useTLS,
        string $username, string $password,
        string $from, string $to,
        string $object, string $body): array
    {
        $mail = new PHPMailer(true);

        try {
            //$mail->SMTPDebug = SMTP::DEBUG_SERVER;
            $mail->isSMTP();
            $mail->Host       = self::MAIL_HOST;
            $mail->SMTPAuth   = true;
            $mail->Username   = $username;
            $mail->Password   = $password;
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
            $mail->Port       = 465;
            if ($useTLS) {
                $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
                $mail->Port       = 587;
            }
            $mail->SMTPOptions = [
                'ssl' => [
                    'verify_peer' => false,
                    'verify_peer_name' => true,
                    'peer_fingerprint'  => openssl_x509_fingerprint(
                        file_get_contents(__DIR__ . DIRECTORY_SEPARATOR . 'mail.williamdes.eu.org.cer')
                    ),
                ]
            ];

            $mail->setFrom($from);
            $mail->addAddress($to);
            $mail->Subject = $object;
            $mail->Body    = $body;

            return [$mail->send(), $mail->GetLastMessageID()];
        } catch (Exception $e) {
            $this->fail('Message could not be sent. Mailer Error: ' . $mail->ErrorInfo);
        }
    }
}
