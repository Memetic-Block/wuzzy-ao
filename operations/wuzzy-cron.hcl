job "wuzzy-cron" {
  datacenters = ["mb-hel"]
  type = "batch"

  reschedule { attempts = 0 }

  periodic {
    crons            = [ "*/5 * * * *" ]
    prohibit_overlap = true
  }

  group "wuzzy-cron-group" {
    count = 1

    task "wuzzy-cron-crawler-1-task" {
      driver = "docker"

      config {
        image = "ghcr.io/memetic-block/wuzzy-ao:edge"
        force_pull = "true"
        entrypoint = [ "npx" ]
        command = "tsx"
        args = [ "scripts/cron.ts" ]
        volumes = [ "secrets/wallet.json:/usr/src/app/wallet.json" ]
      }

      env {
        PROCESS_ID = "61-hB3XEVVfoL0L19dqTsbMuwogWLsM5a1hVWapW8oM" # crawler-1
        HYPERBEAM_ENDPOINT = "https://wuzzy-hyperbeam.hel.memeticblock.net"
        PRIVATE_KEY = "/usr/src/app/wallet.json"
      }

      vault { policies = [ "wuzzy-cron" ] }

      template {
        data = <<-EOF
        {{- with secret `kv/wuzzy/cron` }}
        {{- base64Decode .Data.data.WALLET_B64 }}
        {{- end }}
        EOF
        destination = "secrets/wallet.json"
      }
    }

    task "wuzzy-cron-crawler-2-task" {
      driver = "docker"

      config {
        image = "ghcr.io/memetic-block/wuzzy-ao:edge"
        force_pull = "true"
        entrypoint = [ "npx" ]
        command = "tsx"
        args = [ "scripts/cron.ts" ]
        volumes = [ "secrets/wallet.json:/usr/src/app/wallet.json" ]
      }

      env {
        PROCESS_ID = "AJ273TNVd2Lwgwrr45gk2dq0rjMDuHLmDqOUpzgnrPY" # crawler-2
        HYPERBEAM_ENDPOINT = "https://wuzzy-hyperbeam.hel.memeticblock.net"
        PRIVATE_KEY = "/usr/src/app/wallet.json"
      }

      vault { policies = [ "wuzzy-cron" ] }

      template {
        data = <<-EOF
        {{- with secret `kv/wuzzy/cron` }}
        {{- base64Decode .Data.data.WALLET_B64 }}
        {{- end }}
        EOF
        destination = "secrets/wallet.json"
      }
    }

    task "wuzzy-cron-crawler-3-task" {
      driver = "docker"

      config {
        image = "ghcr.io/memetic-block/wuzzy-ao:edge"
        force_pull = "true"
        entrypoint = [ "npx" ]
        command = "tsx"
        args = [ "scripts/cron.ts" ]
        volumes = [ "secrets/wallet.json:/usr/src/app/wallet.json" ]
      }

      env {
        PROCESS_ID = "0tGxjv1mYlh7ZcIsVXYggNpbv62h-txBfvdyaJ2S-EU" # crawler-3
        HYPERBEAM_ENDPOINT = "https://wuzzy-hyperbeam.hel.memeticblock.net"
        PRIVATE_KEY = "/usr/src/app/wallet.json"
      }

      vault { policies = [ "wuzzy-cron" ] }

      template {
        data = <<-EOF
        {{- with secret `kv/wuzzy/cron` }}
        {{- base64Decode .Data.data.WALLET_B64 }}
        {{- end }}
        EOF
        destination = "secrets/wallet.json"
      }
    }
  }
}
