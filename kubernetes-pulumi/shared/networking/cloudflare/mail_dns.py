import pulumi
import pulumi_cloudflare as cloudflare
from typing import Optional


class MailDnsManager(pulumi.ComponentResource):
    def __init__(
        self,
        name: str,
        domain: pulumi.Output[str],
        zone_id: pulumi.Output[str],
        cf_opts: pulumi.ResourceOptions,
        opts: Optional[pulumi.ResourceOptions] = None,
    ):
        super().__init__("homelab:networking:MailDnsManager", name, {}, opts)

        # Root A Record (Placeholder for Tunnel mapping stability)
        cloudflare.DnsRecord(
            f"{name}-root-a",
            zone_id=zone_id,
            name="smadja.dev",  # Domain is typically constant but we hardcode for smadja.dev root here based on the original logic
            type="A",
            content="192.0.2.1",
            proxied=True,
            ttl=1,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )

        # MX Records
        cloudflare.DnsRecord(
            f"{name}-migadu-mx1",
            zone_id=zone_id,
            name="@",
            type="MX",
            content="aspmx1.migadu.com",
            priority=10,
            ttl=3600,
            proxied=False,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )
        cloudflare.DnsRecord(
            f"{name}-migadu-mx2",
            zone_id=zone_id,
            name="@",
            type="MX",
            content="aspmx2.migadu.com",
            priority=20,
            ttl=3600,
            proxied=False,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )

        # SPF, DMARC, Domain Verify
        cloudflare.DnsRecord(
            f"{name}-migadu-spf",
            zone_id=zone_id,
            name="@",
            type="TXT",
            content="v=spf1 include:spf.migadu.com -all",
            ttl=3600,
            proxied=False,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )
        cloudflare.DnsRecord(
            f"{name}-migadu-dmarc",
            zone_id=zone_id,
            name="_dmarc",
            type="TXT",
            content="v=DMARC1; p=quarantine;",
            ttl=3600,
            proxied=False,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )
        cloudflare.DnsRecord(
            f"{name}-migadu-verify",
            zone_id=zone_id,
            name="@",
            type="TXT",
            content="hosted-email-verify=sd1bfbhe",
            ttl=3600,
            proxied=False,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )

        # DKIM
        for i in range(1, 4):
            cloudflare.DnsRecord(
                f"{name}-migadu-dkim{i}",
                zone_id=zone_id,
                name=f"key{i}._domainkey",
                type="CNAME",
                content=domain.apply(
                    lambda d, idx=i: f"key{idx}.{d}._domainkey.migadu.com"
                ),
                ttl=3600,
                proxied=False,
                opts=pulumi.ResourceOptions.merge(
                    cf_opts, pulumi.ResourceOptions(parent=self)
                ),
            )

        # Autoconfig
        cloudflare.DnsRecord(
            f"{name}-migadu-autoconfig",
            zone_id=zone_id,
            name="autoconfig",
            type="CNAME",
            content="autoconfig.migadu.com",
            ttl=3600,
            proxied=False,
            opts=pulumi.ResourceOptions.merge(
                cf_opts, pulumi.ResourceOptions(parent=self)
            ),
        )

        # SRV Records
        mail_srvs = [
            ("_submissions._tcp", 465, "smtp.migadu.com", "SMTP submission"),
            ("_imaps._tcp", 993, "imap.migadu.com", "IMAPS"),
            ("_pop3s._tcp", 995, "pop.migadu.com", "POP3S"),
            (
                "_autodiscover._tcp",
                443,
                "autodiscover.migadu.com",
                "Outlook autodiscovery",
            ),
        ]
        for srv_name, port, target, comment in mail_srvs:
            cloudflare.DnsRecord(
                f"{name}-migadu-srv-{srv_name.replace('_', '').replace('.', '-')}",
                zone_id=zone_id,
                name=srv_name,
                type="SRV",
                ttl=3600,
                proxied=False,
                data=cloudflare.DnsRecordDataArgs(
                    priority=0, weight=1, port=port, target=target
                ),
                opts=pulumi.ResourceOptions.merge(
                    cf_opts, pulumi.ResourceOptions(parent=self)
                ),
            )
