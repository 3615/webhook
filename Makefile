PHP_VERSION			= 7.3

FIG 				= docker-compose
DOCKER_BUILD_ARGS	= --build-arg PHP_VERSION=$(PHP_VERSION)

TOOLS				= bin/tools

COMPOSER			= $(TOOLS) composer
SYMFONY				= $(TOOLS) bin/console
NPM					= $(TOOLS) npm

QA_IMAGE			= mykiwi/phaudit:$(PHP_VERSION)
QA					= docker pull $(QA_IMAGE); docker run --rm -v `pwd`:/project $(QA_IMAGE)
ARTEFACTS			= var/artefacts

##
## Project
## -------
##

build:
	DOCKER_BUILDKIT=1 docker build --pull $(DOCKER_BUILD_ARGS) --target http-dev  --tag 3615/webhook:dev   .
	DOCKER_BUILDKIT=1 docker build        $(DOCKER_BUILD_ARGS) --target tools     --tag 3615/webhook:tools .
	$(FIG) build

kill:
	$(FIG) kill
	$(FIG) down --remove-orphans --volumes

install: ## Install and start the project
install: build start db

reset: ## Stop and start a fresh install of the project
reset: kill install

start: ## Start the project
	$(FIG) up -d --remove-orphans --no-recreate
	$(FIG) ps

stop: ## Stop the project
	$(FIG) stop

clean: ## Stop the project and remove generated files
clean: kill
	rm -rf vendor var/cache/* var/log/*

.PHONY: build kill install reset start stop clean

##
## Utils
## -----
##

update-deps:
	$(COMPOSER) update
	$(COMPOSER) outdated
	$(NPM) update
	$(NPM) outdated

db: ## Reset the database and load fixtures
db: .env vendor
	@$(EXEC_PHP) php -r 'echo "Wait database...\n"; set_time_limit(15); require __DIR__."/vendor/autoload.php"; (new \Symfony\Component\Dotenv\Dotenv())->load(__DIR__."/.env"); $$u = parse_url(getenv("DATABASE_URL")); for(;;) { if(@fsockopen($$u["host"].":".($$u["port"] ?? 5432))) { break; }}'
	-$(SYMFONY) doctrine:database:drop --if-exists --force
	-$(SYMFONY) doctrine:database:create --if-not-exists
	$(SYMFONY) doctrine:migrations:migrate --no-interaction --allow-no-migration
	$(SYMFONY) doctrine:fixtures:load --no-interaction --purge-with-truncate

migration: ## Generate a new doctrine migration
migration: vendor
	$(SYMFONY) doctrine:migrations:diff

db-validate-schema: ## Validate the doctrine ORM mapping
db-validate-schema: .env vendor
	$(SYMFONY) doctrine:schema:validate

assets: ## Run Webpack Encore to compile assets
assets: node_modules
	$(YARN) run dev

watch: ## Run Webpack Encore in watch mode
watch: node_modules
	$(YARN) run watch

.PHONY: db migration assets watch

##
## Tests
## -----
##

test: ## Run unit and functional tests
test: tu tf

tu: ## Run unit tests
tu: vendor
	$(EXEC_PHP) bin/phpunit --exclude-group functional

tf: ## Run functional tests
tf: vendor
	$(EXEC_PHP) bin/phpunit --group functional

.PHONY: test tu tf

# rules based on files
composer.lock: composer.json
	$(COMPOSER) update --lock --no-scripts --no-interaction

vendor: composer.lock
	$(COMPOSER) install

.env.local: .env
	@if [ -f .env ]; \
	then\
		echo '\033[1;41m/!\ The .env file has changed. Please check your .env.local file (this message will not be displayed again).\033[0m';\
		touch .env.local;\
		exit 1;\
	fi


# ################# #
# Quality Assurance #
# ################# #

lint: lt ly

lt: vendor
	$(SYMFONY) lint:twig templates

ly: vendor
	$(SYMFONY) lint:yaml config

security: vendor
	$(EXEC_PHP) ./vendor/bin/security-checker security:check

phploc:
	$(QA) phploc src/

pdepend: artefacts
	$(QA) pdepend \
		--summary-xml=$(ARTEFACTS)/pdepend_summary.xml \
		--jdepend-chart=$(ARTEFACTS)/pdepend_jdepend.svg \
		--overview-pyramid=$(ARTEFACTS)/pdepend_pyramid.svg \
		src/

phpmd:
	$(QA) phpmd src text .phpmd.xml

php_codesnifer:
	$(QA) phpcs -v --standard=.phpcs.xml src

phpcpd:
	$(QA) phpcpd src

phpdcd:
	$(QA) phpdcd src

phpmetrics: artefacts
	$(QA) phpmetrics --report-html=$(ARTEFACTS)/phpmetrics src

php-cs-fixer:
	$(QA) php-cs-fixer fix --dry-run --using-cache=no --verbose --diff

apply-php-cs-fixer:
	$(QA) php-cs-fixer fix --using-cache=no --verbose --diff

twigcs:
	$(QA) twigcs lint templates

eslint: node_modules
	$(EXEC_JS) node_modules/.bin/eslint --fix-dry-run assets/js/**

artefacts:
	mkdir -p $(ARTEFACTS)

.PHONY: lint lt ly phploc pdepend phpmd php_codesnifer phpcpd phpdcd phpmetrics php-cs-fixer apply-php-cs-fixer artefacts





.DEFAULT_GOAL := help
help:
	@grep -E '(^[a-zA-Z_-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'
.PHONY: help
