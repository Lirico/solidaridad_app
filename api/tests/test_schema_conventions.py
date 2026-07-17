from sqlalchemy import BigInteger, Identity, String

from persistence.models import Base


def test_all_tables_use_surrogate_bigint_identity_primary_keys() -> None:
    for table in Base.metadata.sorted_tables:
        assert "id" in table.c, f"{table.name} must define an id column"
        column = table.c.id
        assert column.primary_key, f"{table.name}.id must be the primary key"
        assert isinstance(column.type, BigInteger)
        assert isinstance(column.server_default, Identity)


def test_installation_id_is_an_8_character_unique_business_key() -> None:
    table = Base.metadata.tables["installations"]
    column = table.c.installation_id

    assert isinstance(column.type, String)
    assert column.type.length == 8
    assert not column.nullable
    assert column.unique
