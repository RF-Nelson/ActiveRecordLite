require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    whereline = params.keys.map { |key| "#{key} = ?" }.join(" AND ")
    query = DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{whereline}
      SQL
    parse_all(query)
  end
end

class SQLObject
  extend Searchable
end
