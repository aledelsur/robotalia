require "zip"

# Writes a synthetic .xlsx file with the cell layout of an MT5 "Trade History Report".
# All account details, robot names and trades are invented.
#
# Regenerate the committed sample after changing it:
#   bin/rails runner -e test 'require Rails.root.join("spec/support/mt5_report_builder").to_s; Mt5ReportBuilder.new.write(Rails.root.join("spec/fixtures/files/mt5_report_sample.xlsx"))'
class Mt5ReportBuilder
  POSITION_HEADER = [ "Time", "Position", "Symbol", "Type", "Volume", "Price", "S / L", "T / P",
                      "Time", "Price", "Commission", "Swap", "Profit" ].freeze
  DEAL_HEADER = [ "Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price", "Order",
                  "Commission", "Fee", "Swap", "Profit", "Balance", "Comment" ].freeze

  POSITIONS = [
    # Buy closed at take profit.
    [ "2026.03.02 09:00:00", 5001, "EURUSD", "buy", "0.10", 1.08, 1.078, 1.084,
      "2026.03.02 12:00:00", 1.084, -0.7, 0.0, 40.0 ],
    # Sell closed at stop loss, held overnight.
    [ "2026.03.03 10:00:00", 5002, "GBPUSD", "sell", "0.20", 1.27, 1.271, 1.267,
      "2026.03.04 08:00:00", 1.271, -1.4, -0.35, -20.0 ],
    # Manual trade without a comment.
    [ "2026.03.05 11:00:00", 5003, "XAUUSD", "buy", "0.01", 2900.5, nil, nil,
      "2026.03.05 15:00:00", 2910.5, 0.0, 0.0, 10.0 ],
    # One position closed in two parts.
    [ "2026.03.06 09:00:00", 5004, "EURUSD", "buy", "0.10", 1.09, 1.088, 1.095,
      "2026.03.06 10:00:00", 1.092, -0.35, 0.0, 20.0 ],
    [ "2026.03.06 09:00:00", 5004, "EURUSD", "buy", "0.10", 1.09, 1.088, 1.095,
      "2026.03.06 11:00:00", 1.094, -0.35, 0.0, 40.0 ],
    # Malformed: the open time is not a time.
    [ "2026.03.09 ??", 5005, "EURUSD", "buy", "0.10", 1.09, nil, nil,
      "2026.03.09 11:00:00", 1.091, 0.0, 0.0, 10.0 ]
  ].freeze

  def self.deal(time, ticket, symbol, side, direction, volume, price, order, profit, comment, commission: 0.0, swap: 0.0)
    [ time, ticket, symbol, side, direction, volume, price, order, commission, 0.0, swap, profit, 0.0, comment ]
  end

  def self.balance(time, ticket, amount, comment)
    [ time, ticket, nil, "balance", nil, nil, nil, nil, 0.0, 0.0, 0.0, amount, 0.0, comment ]
  end

  DEALS = [
    balance("2026.03.01 08:00:00", 9000, 1000.0, "Deposit"),
    deal("2026.03.02 09:00:00", 9001, "EURUSD", "buy", "in", "0.10", 1.08, 5001, 0.0, "Trend_Long", commission: -0.35),
    deal("2026.03.02 12:00:00", 9002, "EURUSD", "sell", "out", "0.10", 1.084, 6001, 40.0, "[tp 1.08400]", commission: -0.35),
    deal("2026.03.03 10:00:00", 9003, "GBPUSD", "sell", "in", "0.20", 1.27, 5002, 0.0, "Range_Short", commission: -0.7),
    deal("2026.03.04 08:00:00", 9004, "GBPUSD", "buy", "out", "0.20", 1.271, 6002, -20.0, "[sl 1.27100]", commission: -0.7, swap: -0.35),
    deal("2026.03.05 11:00:00", 9005, "XAUUSD", "buy", "in", "0.01", 2900.5, 5003, 0.0, nil),
    deal("2026.03.05 15:00:00", 9006, "XAUUSD", "sell", "out", "0.01", 2910.5, 6003, 10.0, nil),
    deal("2026.03.06 09:00:00", 9007, "EURUSD", "buy", "in", "0.20", 1.09, 5004, 0.0, "Trend_Long", commission: -0.35),
    deal("2026.03.06 10:00:00", 9008, "EURUSD", "sell", "out", "0.10", 1.092, 6004, 20.0, nil, commission: -0.17),
    deal("2026.03.06 11:00:00", 9009, "EURUSD", "sell", "out", "0.10", 1.094, 6005, 40.0, nil, commission: -0.18),
    balance("2026.03.10 08:00:00", 9010, -100.0, "Withdrawal")
  ].freeze

  def initialize(positions: POSITIONS, deals: DEALS, account: "1234567 (USD, ExampleBroker-Demo, demo, Hedge)")
    @positions = positions
    @deals = deals
    @account = account
  end

  def rows
    [
      [ "Trade History Report" ],
      [ "Name:", nil, nil, "Sample Owner" ],
      [ "Account:", nil, nil, @account ],
      [ "Company:", nil, nil, "Example Broker" ],
      [ "Date:", nil, nil, "2026.03.11 09:00" ],
      [ "Positions" ], POSITION_HEADER, *@positions,
      [],
      [ "Orders" ], [ "Open Time", "Order" ], [ "2026.03.02 09:00:00", 5001 ],
      [],
      [ "Deals" ], DEAL_HEADER, *@deals,
      [ nil, nil, nil, nil, nil, nil, nil, nil, -2.45, 0.0, -0.35, 990.0 ],
      [ "Balance:", nil, nil, 987.2 ],
      [ "Results" ], [ "Total Net Profit:", nil, nil, 87.2 ]
    ]
  end

  def write(path)
    File.delete(path) if File.exist?(path)
    Zip::File.open(path.to_s, create: true) do |zip|
      parts.each { |name, xml| zip.get_output_stream(name) { |stream| stream.write(xml) } }
    end
    path
  end

  private
    def parts
      main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
      relationships = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
      package = "http://schemas.openxmlformats.org/package/2006"
      content = "application/vnd.openxmlformats-officedocument.spreadsheetml"

      {
        "[Content_Types].xml" => <<~XML,
          <Types xmlns="#{package}/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="#{content}.sheet.main+xml"/>
            <Override PartName="/xl/styles.xml" ContentType="#{content}.styles+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="#{content}.worksheet+xml"/>
          </Types>
        XML
        "_rels/.rels" => <<~XML,
          <Relationships xmlns="#{package}/relationships">
            <Relationship Id="rId1" Type="#{relationships}/officeDocument" Target="xl/workbook.xml"/>
          </Relationships>
        XML
        "xl/styles.xml" => %(<styleSheet xmlns="#{main}"><cellXfs count="1"><xf numFmtId="0"/></cellXfs></styleSheet>),
        "xl/workbook.xml" => <<~XML,
          <workbook xmlns="#{main}" xmlns:r="#{relationships}">
            <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
          </workbook>
        XML
        "xl/_rels/workbook.xml.rels" => <<~XML,
          <Relationships xmlns="#{package}/relationships">
            <Relationship Id="rId1" Type="#{relationships}/worksheet" Target="worksheets/sheet1.xml"/>
          </Relationships>
        XML
        "xl/worksheets/sheet1.xml" => %(<worksheet xmlns="#{main}"><sheetData>#{sheet_rows}</sheetData></worksheet>)
      }
    end

    def sheet_rows
      rows.each_with_index.map do |row, r|
        cells = row.each_with_index.filter_map { |value, c| cell(value, "#{("A".ord + c).chr}#{r + 1}") }
        %(<row r="#{r + 1}">#{cells.join}</row>)
      end.join
    end

    def cell(value, ref)
      case value
      when nil then nil
      when Numeric then %(<c r="#{ref}"><v>#{value}</v></c>)
      else %(<c r="#{ref}" t="inlineStr"><is><t>#{value.to_s.encode(xml: :text)}</t></is></c>)
      end
    end
end
