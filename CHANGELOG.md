## dbt-iomete 1.2.0 (Nov 13, 2022)
- Full schema sync works with Iceberg tables as well

## dbt-iomete 1.1.0 (Nov 7, 2022)
Update iomete connection parameters and improve error messaging

- Improve error messaging
- Update profile template to reflect the new iomete parameters
- moved to py-hive-iomete from py-hive
- changed cluster parameter to lakehouse

## dbt-iomete 1.0.2 (Sep 20, 2022)
- `profile_template.yml` Updated according to previous release 1.0.1

## dbt-iomete 1.0.1 (Sep 18, 2022)
- Added new connection parameter `account_number`, based on new format of Lakehouse JDBC connection url.
To enable the Lakehouse connection, you need to add the account_number parameter to the ~/.dbt/profiles.yml file.
Follow profile [documentation](https://docs.iomete.com/docs/profile-setup)

## dbt-iomete 1.0.0 (May 25, 2022)
- dbt-iomete adapter implemented and released ([here](https://github.com/iomete/dbt-iomete/commit/e692dfb8b59ff699ee546ecef7ae46388e2352f5))