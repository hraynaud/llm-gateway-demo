# Added 2026: plain-text output for bin/search, kept out of the script so it is testable.
module Demo
  module Report
    DIVIDER = '--- weaker matches (not clearly above the crowd) ---'.freeze

    module_function

    def header(enrich_provider:, enrich_model:, embed_provider:, embed_model:)
      "Enrichment: #{enrich_provider} (#{enrich_model}) · Embeddings: #{embed_provider} (#{embed_model})"
    end

    def strength(z)
      format('%+.1fσ', z)
    end

    def movement(change)
      return '' if change.zero?

      change.positive? ? "↑#{change}" : "↓#{-change}"
    end

    # Rows arrive highest score first, so strong rows come first; divide before the first weak one.
    def with_divider(rows)
      lines = []
      rows.each do |row|
        lines << DIVIDER if !row[:strong] && !lines.include?(DIVIDER)
        lines << yield(row)
      end
      lines
    end

    def compare_lines(rows)
      head = format('%-22s %-19s %-12s %s', 'name', 'enriched', 'bare', 'move')
      body = with_divider(rows) do |r|
        line = format('%-22s %2d %.3f %-6s %2d %.3f   %-4s', r[:name], r[:enriched_rank], r[:enriched_score],
                      strength(r[:strength]), r[:bare_rank], r[:bare_score], movement(r[:rank_change])).rstrip
        r[:gained] ? "#{line} <- found via enrichment" : line
      end
      [head, *body]
    end

    def query_lines(results)
      with_divider(results) { |r| format('%.3f %-6s %s', r[:score], strength(r[:strength]), r[:name]) }
    end

    def eval_lines(result)
      rank = ->(n) { n ? n.to_s : '-' }
      row_format = '%-50s %-6s %8s %5s  %s'
      head = format(row_format, 'query', 'level', 'enriched', 'bare', 'verdict')
      rows = result[:rows].map do |r|
        format(row_format, r[:query][0, 50], r[:difficulty], rank.call(r[:enriched_rank]), rank.call(r[:bare_rank]), r[:verdict])
      end
      s = result[:summary]
      [head, *rows, '',
       format('enriched: %d/%d at #1, %d/%d in top %d', s[:enriched_hit1], s[:total], s[:enriched_hitk], s[:total], s[:k]),
       format('bare:     %d/%d at #1, %d/%d in top %d', s[:bare_hit1], s[:total], s[:bare_hitk], s[:total], s[:k]),
       format('enrichment helped %d, hurt %d, same %d', s[:helped], s[:hurt], s[:same])]
    end
  end
end
