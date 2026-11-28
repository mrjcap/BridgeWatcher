Describe -Name 'SIEM forwarding configuration' -Fixture {
    BeforeAll -Scriptblock {
        $script:root = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:compose = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'docker-compose.yml') -Raw
        $script:logstash = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'Docker/filebeat.yml') -Raw
        $script:elasticsearch = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'Docker/filebeat.elasticsearch.yml') -Raw
        $script:syslog = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'docker-compose.syslog.yml') -Raw
    }

    It -Name 'Contains no placeholder hosts or credentials in tracked configuration' -Test {
        foreach ($text in @($script:compose, $script:logstash, $script:elasticsearch, $script:syslog)) {
            $text | Should -Not -Match -RegularExpression 'your-[a-z-]*host'
            $text | Should -Not -Match -RegularExpression 'changeme'
        }
    }

    It -Name 'Takes the Logstash target from environment variables' -Test {
        $script:logstash | Should -Match -RegularExpression 'hosts:\s*\["\$\{LOGSTASH_HOST\}:\$\{LOGSTASH_PORT:5044\}"\]'
    }

    It -Name 'Takes the Elasticsearch target and API key from environment variables' -Test {
        $script:elasticsearch | Should -Match -RegularExpression '\$\{ELASTICSEARCH_HOST\}'
        $script:elasticsearch | Should -Match -RegularExpression 'api_key:\s*"\$\{ELASTICSEARCH_API_KEY\}"'
    }

    It -Name 'Lets the compose file select the Filebeat configuration and passes the variables through' -Test {
        $script:compose | Should -Match -RegularExpression '\$\{FILEBEAT_CONFIG:-\./Docker/filebeat\.yml\}:/usr/share/filebeat/filebeat\.yml:ro'
        foreach ($name in 'LOGSTASH_HOST', 'ELASTICSEARCH_HOST', 'ELASTICSEARCH_API_KEY') {
            $script:compose | Should -Match -RegularExpression "(?m)^\s+-\s+$name\s*$"
        }
    }

    It -Name 'Runs Filebeat with a read-only root filesystem and explicit writable paths' -Test {
        $section = (($script:compose -split '(?m)^\s{2}filebeat:\r?\n')[1] -split '(?m)^volumes:\r?\n')[0]
        $section | Should -Match -RegularExpression '(?m)^\s+read_only:\s*true'
        $section | Should -Match -RegularExpression '/usr/share/filebeat/data'
        $section | Should -Match -RegularExpression '(?m)^\s+-\s+/usr/share/filebeat/logs\s*$'
    }

    It -Name 'Provides syslog forwarding as an override that requires SYSLOG_ADDRESS' -Test {
        $script:syslog | Should -Match -RegularExpression 'driver:\s*syslog'
        $script:syslog | Should -Match -RegularExpression '\$\{SYSLOG_ADDRESS:\?'
    }

    It -Name 'Keeps syslog out of the base compose file' -Test {
        $script:compose | Should -Not -Match -RegularExpression 'syslog'
    }
}
