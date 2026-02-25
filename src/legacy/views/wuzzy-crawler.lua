-- module_id ZK1AXFffVJ2XNNIt5-s6NsI7r_nrsatoRdHyqSKs6xk

function crawler_info(base, req)
  local state = base.WuzzyCrawler.State
  local result = {
    owner = base.owner,
    nest_id = state.NestId,
    gateway = state.Gateway,
    total_crawl_tasks = #state.CrawlTasks,
    crawl_queue_size = #state.CrawlQueue,
    crawled_urls_memory_size = #state.CrawledURLs
  }

  for i, task in ipairs(state.CrawlTasks) do
    result['crawl_task_'..i..'_added_by'] = task.AddedBy
    result['crawl_task_'..i..'_url'] = task.URL
    result['crawl_task_'..i..'_submitted_url'] = task.SubmittedUrl
    result['crawl_task_'..i..'_domain'] = task.Domain
  end

  for i, item in ipairs(state.CrawlQueue) do
    result['crawl_queue_item_'..i..'_url'] = item.URL
    result['crawl_queue_item_'..i..'_domain'] = item.Domain
    result['crawl_queue_item_'..i..'_added_at'] = item.AddedAt
  end

  for i, item in ipairs(state.CrawledURLs) do
    result['crawled_url_'..i] = item
  end

  return result
end
