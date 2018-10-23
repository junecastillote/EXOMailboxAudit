<p>
One of the things that don’t happen automatically when provisioning an Office 365 Mailbox is getting the Mailbox Audit Enabled. This script can be run manually or by schedule to enable auditing on mailboxes.</p>
<h3>
Download Link</h3>
<p>
<a title="https://github.com/junecastillote/Enable-EXOMailboxAudit" href="https://github.com/junecastillote/Enable-EXOMailboxAudit">https://github.com/junecastillote/Enable-EXOMailboxAudit</a></p>
<h3>

</h3>
<h3>
Requirements</h3>
<ul>
<li>The Office 365 account to be used to run the script must be assigned an Exchange Administrator role in order to read and set mailbox audit settings.</li>
<li>Must have a mailbox to be able to send the email report using Office 365 SMTP Relay</li>
</ul>
<h4>

</h4>
<h3>
Office 365 Credentials</h3>
<p>
This script uses an encrypted credential (XML). To store the credential:<ul>
<li>Login to the Server/Computer using the account that will be used to run the script/task</li>
<li>Run this "<em>Get-Credential | Export-CliXml Office365StoredCredential.xml</em>"</li>
<li>Make sure that <strong><u>Office365StoredCredential.xml</u></strong> is in the same folder as the script.</li>
</ul>
<p>

</p>
<h3>
Modify Variables</h3>
<p>
<a href="https://lh3.googleusercontent.com/-1yWAXlXHBgk/W7D37WZg3GI/AAAAAAAADNg/gdoYRukjZf8-SfSRzpkmsGUU-STbuoz2gCHMYCw/s1600-h/Code_2018-10-01_00-11-15%255B2%255D"><img width="590" height="86" title="" style="display: inline; background-image: none;" alt="" src="https://lh3.googleusercontent.com/-8AVx9yrQaiU/W7D38l5YHVI/AAAAAAAADNk/4VFIQ3_pDwU4RzFBLdqyt5X5rim968tiQCHMYCw/Code_2018-10-01_00-11-15_thumb?imgmax=800" border="0"></a></p>
<ul>
<li>$sendEmail – set to $true or $false depending on whether you’d like the report to be send to email</li>
<li>$sender – This is the Sender Email Address – make sure this is the email address or the Office 365 Credential you are using for the script.</li>
<li>$recipients – These are the recipient addresses. To add multiple recipients, separate with comma.</li>
<li>$subject – This will show as the subject of the email report.</li>
</ul>
<p>

</p>
<h3>
Run the script</h3>
<p>
The script requires no parameters.</p>
<p>
<a href="https://lh3.googleusercontent.com/-swzVIMP8rxU/W7D3-IWWRcI/AAAAAAAADNo/v8trywJd8hAWthfkxXIGHXDwkcaplcxyQCHMYCw/s1600-h/2018-10-01_00-09-50%255B3%255D"><img width="828" height="295" title="" style="display: inline;" alt="" src="https://lh3.googleusercontent.com/-rtrKcdx7mNA/W7D3_XwuhjI/AAAAAAAADNs/R8M1kqB4xtQy4KZzv2aFBO_zXuoAMVB3gCHMYCw/2018-10-01_00-09-50_thumb%255B1%255D?imgmax=800"></a></p>
<h3>
Sample Report</h3>
<h4>
Email</h4>
<p>
<a href="https://lh3.googleusercontent.com/-JvIFjmU2L4g/W7D4AIklq9I/AAAAAAAADNw/Xw9bPQLjkXAELK7qrlhxf0SmLZHXsVPfACHMYCw/s1600-h/mRemoteNG_2018-10-01_00-10-08%255B2%255D"><img width="719" height="344" title="" style="display: inline; background-image: none;" alt="" src="https://lh3.googleusercontent.com/-wuj8eFVkXVE/W7D4BbqsuUI/AAAAAAAADN0/QU7hzhgWcJQEvN8m7Embbf8-yJf-yu4vQCHMYCw/mRemoteNG_2018-10-01_00-10-08_thumb?imgmax=800" border="0"></a></p>
<p>
CSV</p>
<p>
<a href="https://lh3.googleusercontent.com/-_ox_A2Vw6C4/W7D4CWjd_8I/AAAAAAAADN4/xM8z6nfguloFmHoC3qyGx_0XUvi5odzEwCHMYCw/s1600-h/mRemoteNG_2018-10-01_00-10-20%255B2%255D"><img width="362" height="136" title="" style="display: inline; background-image: none;" alt="" src="https://lh3.googleusercontent.com/-JM75oGXQpV8/W7D4DtmHFVI/AAAAAAAADN8/05sJj2cXjx0AHkApWX-SSE-xeJB2o37AQCHMYCw/mRemoteNG_2018-10-01_00-10-20_thumb?imgmax=800" border="0"></a></p>
