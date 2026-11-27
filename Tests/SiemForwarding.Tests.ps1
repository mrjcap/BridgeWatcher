Describe 'SIEM forwarding configuration' {
    BeforeAll {
        $script:root = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath '..'))
        $script:compose = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'docker-compose.yml') -Raw
        $script:logstash = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'Docker/filebeat.yml') -Raw
        $script:elasticsearch = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'Docker/filebeat.elasticsearch.yml') -Raw
        $script:syslog = Get-Content -Path (Join-Path -Path $script:root -ChildPath 'docker-compose.syslog.yml') -Raw
    }

    It 'Contains no placeholder hosts or credentials in tracked configuration' {
        foreach ($text in @($script:compose, $script:logstash, $script:elasticsearch, $script:syslog)) {
            $text | Should -Not -Match 'your-[a-z-]*host'
            $text | Should -Not -Match 'changeme'
        }
    }

    It 'Takes the Logstash target from environment variables' {
        $script:logstash | Should -Match 'hosts:\s*\["\$\{LOGSTASH_HOST\}:\$\{LOGSTASH_PORT:5044\}"\]'
    }

    It 'Takes the Elasticsearch target and API key from environment variables' {
        $script:elasticsearch | Should -Match '\$\{ELASTICSEARCH_HOST\}'
        $script:elasticsearch | Should -Match 'api_key:\s*"\$\{ELASTICSEARCH_API_KEY\}"'
    }

    It 'Lets the compose file select the Filebeat configuration and passes the variables through' {
        $script:compose | Should -Match '\$\{FILEBEAT_CONFIG:-\./Docker/filebeat\.yml\}:/usr/share/filebeat/filebeat\.yml:ro'
        foreach ($name in 'LOGSTASH_HOST', 'ELASTICSEARCH_HOST', 'ELASTICSEARCH_API_KEY') {
            $script:compose | Should -Match "(?m)^\s+-\s+$name\s*$"
        }
    }

    It 'Runs Filebeat with a read-only root filesystem and explicit writable paths' {
        $section = (($script:compose -split '(?m)^\s{2}filebeat:\r?\n')[1] -split '(?m)^volumes:\r?\n')[0]
        $section | Should -Match '(?m)^\s+read_only:\s*true'
        $section | Should -Match '/usr/share/filebeat/data'
        $section | Should -Match '(?m)^\s+-\s+/usr/share/filebeat/logs\s*$'
    }

    It 'Provides syslog forwarding as an override that requires SYSLOG_ADDRESS' {
        $script:syslog | Should -Match 'driver:\s*syslog'
        $script:syslog | Should -Match '\$\{SYSLOG_ADDRESS:\?'
    }

    It 'Keeps syslog out of the base compose file' {
        $script:compose | Should -Not -Match 'syslog'
    }
}
