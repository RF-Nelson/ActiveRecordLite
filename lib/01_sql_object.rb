require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns if @columns
    temp = DBConnection.execute2("
        SELECT
          *
        FROM
          #{self.table_name}")[0]

    @columns = temp.map!(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |name|
      define_method(name) do
        self.attributes[name]
      end

      define_method("#{name}=") do |value|
        self.attributes[name] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
   @table_name || self.name.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map { |result| self.new(result) }
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
      SQL
    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |key, value|
      att_name = key.to_sym
      if self.class.columns.include?(att_name)
        self.send("#{att_name}=", value)
      else
        raise "unknown attribute '#{att_name}'"
      end
    end
  end

  def attributes
    @attributes ||= Hash.new
  end

  def attribute_values
    self.class.columns.map { |attribute| self.send(attribute) }
  end

  def insert
    column_names = self.class.columns.map(&:to_s).join(", ")
    q_marks = (["?"] * self.class.columns.count).join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{column_names})
      VALUES
        (#{q_marks})
      SQL
      self.id = DBConnection.last_insert_row_id
  end

  def update
    line = self.class.columns.map {|el| "#{el} = ?"}.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{line}
      WHERE
        #{self.class.table_name}.id = ?
      SQL
  end

  def save
    if id.nil?
      insert
    else
      update
    end
  end

end
