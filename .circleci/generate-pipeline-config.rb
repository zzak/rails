require "digest"
require "fileutils"

SUPPORTED_RUBIES = ["2.7", "3.0", "3.1", "latest"]

def digest tag
  Digest::SHA2.hexdigest(tag)
end

def image_tag
  digest "#{ENV["CIRCLE_PROJECT_USER"]}.#{ENV["CIRCLE_BRANCH"]}"
end

def image_label ruby
  "zzak/rails-ci:v1-ruby-#{ruby}-#{image_tag}"
end

def write cfg
  File.open("configs/generated_config.yml", "w") do |f|
    f.write cfg
  end
end

def config
  return <<-EOF
version: 2.1

orbs:
  browser-tools: circleci/browser-tools@1.2.3

commands:
  run-tests:
    parameters:
      tag:
        type: string
      gem:
        type: string
      command:
        type: string
        default: rake test
    steps:
      - run:
          name: Run tests
          command: |
            export APP_IMAGE_TAG=<< parameters.tag >>
            set +e
            .circleci/with-retry.sh \\
            env COMPOSE_TLS_VERSION=TLSv1_2 \\
            docker-compose -f .circleci/docker-compose.yml run app runner << parameters.gem >> "<< parameters.command >>"

  bundle-restore:
    parameters:
      ruby:
        type: string
    steps:
      - restore_cache:
          keys:
            - gem-cache-v1-ruby-<< parameters.ruby >>-{{ .Branch }}-{{ checksum "Gemfile.lock" }}
            - gem-cache-v1-ruby-<< parameters.ruby >>-{{ .Branch }}
            - gem-cache-v1-ruby-<< parameters.ruby >>
      - restore_cache:
          keys:
            - yarn-cache-v1-ruby-<< parameters.ruby >>-{{ .Branch }}-{{ checksum "yarn.lock" }}
            - yarn-cache-v1-ruby-<< parameters.ruby >>-{{ .Branch }}
            - yarn-cache-v1-ruby-<< parameters.ruby >>

  bundle-install:
    parameters:
      ruby:
        type: string
      tag:
        type: string
    steps:
      - bundle-restore:
          ruby: << parameters.ruby >>
      - run:
          name: Bundle install
          command: |
            export APP_IMAGE_TAG=<< parameters.tag >> \\
            env COMPOSE_TLS_VERSION=TLSv1_2 \\
            docker-compose -f .circleci/docker-compose.yml run app install-deps
      - save_cache:
          key: gem-cache-v1-ruby-<< parameters.ruby >>-{{ .Branch }}-{{ checksum "Gemfile.lock" }}
          paths:
            - vendor/bundler
      - save_cache:
          key: yarn-cache-v1-ruby-<< parameters.ruby >>-{{ .Branch }}-{{ checksum "yarn.lock" }}
          paths:
            - ~/.cache/yarn

jobs:
  build-image:
    parameters:
      ruby:
        type: string
      tag:
        type: string
    machine:
      image: ubuntu-2004:202111-02
      docker_layer_caching: true
      resource_class: large
    environment:
      DOCKER_BUILDKIT: 1
      RUBY_IMAGE: ruby:<< parameters.ruby >>
    steps:
      - checkout
      - run:
          name: Login to docker hub
          command: docker login -u $REGISTRY_USER -p $REGISTRY_PASS
      - run:
          name: Build application Docker image
          command: |
            docker build \\
              --cache-from=<< parameters.tag >> \\
              --tag=<< parameters.tag >> \\
              --build-arg BUILDKIT_INLINE_CACHE=1 \\
              --build-arg RUBY_IMAGE=$RUBY_IMAGE \\
              -f .circleci/Dockerfile .
      - run:
          name: Push to docker hub
          command: |
            docker push << parameters.tag >>

  install-deps:
    parameters:
      ruby:
        type: string
      tag:
        type: string
    machine:
      image: ubuntu-2004:202111-02
      docker_layer_caching: true
      resource_class: large
    steps:
      - checkout
      - run:
          name: Pull build image
          command: |
            docker pull << parameters.tag >>
      - bundle-install:
          ruby: << parameters.ruby >>
          tag: << parameters.tag >>

  test-job:
    parameters:
      gem:
        type: string
      command:
        type: string
        default: rake test
      mysql:
        type: string
        default: mysql:latest
      mysql_prepared_statements:
        type: boolean
        default: false
      ruby:
        type: string
      tag:
        type: string
      nodes:
        type: integer
        default: 1
    machine:
      image: ubuntu-2004:202111-02
      docker_layer_caching: true
      resource_class: large
    parallelism: << parameters.nodes >>
    environment:
      MYSQL_IMAGE: << parameters.mysql >>
      MYSQL_PREPARED_STATEMENTS: << parameters.mysql_prepared_statements >>
    steps:
      - checkout
      - bundle-restore:
          ruby: << parameters.ruby >>
      - run:
          name: Pull build image
          command: |
            docker pull << parameters.ruby >>
      - run-tests:
          tag: << parameters.tag >>
          gem: << parameters.gem >>
          command: << parameters.command >>
      - store_test_results:
          path: test-reports
      - store_artifacts:
          path: test-reports

workflows:
  version: 2
#{workflows}
EOF
end

def workflows
  output = ""
  SUPPORTED_RUBIES.each do |ruby|
    output << <<-EOF
  ruby-#{ruby}:
EOF
    output << jobs(ruby, image_label(ruby))
  end
  output
end

def jobs ruby, tag
  return <<-EOF
    jobs:
      - build-image:
          ruby: "#{ruby}"
          tag: #{tag}
      - install-deps:
          name: install-deps
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - build-image
      - test-job:
          name: actioncable
          gem: actioncable
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      #- actioncable-integration
      - test-job:
          name: actionmailbox
          gem: actionmailbox
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: actionmailer
          gem: actionmailer
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: actionpack
          gem: actionpack
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: actiontext
          gem: actiontext
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: actionview
          gem: actionview
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: actionview-ujs
          gem: actionview
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:ujs
          requires:
            - install-deps
      - test-job:
          name: activestorage
          gem: activestorage
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: activesupport
          gem: activesupport
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: guides
          gem: guides
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: activejob
          gem: activejob
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: activemodel
          gem: activemodel
          ruby: "#{ruby}"
          tag: #{tag}
          requires:
            - install-deps
      - test-job:
          name: railties
          gem: railties
          ruby: "#{ruby}"
          tag: #{tag}
          nodes: 12
          requires:
            - install-deps
      - test-job:
          name: activerecord-mysql2
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake db:mysql:rebuild mysql2:test
          requires:
            - install-deps
      - test-job:
          name: activrecord-mysql2-mariadb
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake db:mysql:rebuild mysql2:test
          mysql: mariadb:latest
          requires:
            - install-deps
      - test-job:
          name: activrecord-mysql2-prepared-statements
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake db:mysql:rebuild mysql2:test
          mysql_prepared_statements: true
          requires:
            - install-deps
      - test-job:
          name: activerecord-postgresql
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake db:postgresql:rebuild postgresql:test
          requires:
            - install-deps
      - test-job:
          name: activerecord-sqlite3
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake sqlite3:test
          requires:
            - install-deps
      - test-job:
          name: activerecord-sqlite3_mem
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake sqlite3_mem:test
          requires:
            - install-deps
      - test-job:
          name: activrecord-mysql2-isolated
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake db:mysql:rebuild mysql2:isolated_test
          nodes: 5
          requires:
            - install-deps
      - test-job:
          name: activerecord-postgresql-isolated
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake db:postgresql:rebuild postgresql:isolated_test
          nodes: 5
          requires:
            - install-deps
      - test-job:
          name: activerecord-sqlite3-isolated
          gem: activerecord
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake sqlite3:isolated_test
          nodes: 5
          requires:
            - install-deps
      - test-job:
          name: actionmailer-isolated
          gem: actionmailer
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:isolated
          requires:
            - install-deps
      - test-job:
          name: actionpack-isolated
          gem: actionpack
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:isolated
          requires:
            - install-deps
      - test-job:
          name: actionview-isolated
          gem: actionview
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:isolated
          requires:
            - install-deps
      - test-job:
          name: activejob-isolated
          gem: activejob
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:isolated
          requires:
            - install-deps
      - test-job:
          name: activemodel-isolated
          gem: activemodel
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:isolated
          requires:
            - install-deps
      - test-job:
          name: activesupport-isolated
          gem: activesupport
          ruby: "#{ruby}"
          tag: #{tag}
          command: rake test:isolated
          requires:
            - install-deps
EOF
end

FileUtils.mkdir_p "configs/"

write config
