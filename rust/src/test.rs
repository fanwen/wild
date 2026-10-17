use crate::wenku8::Wenku8Client;
use crate::CLIENT;

fn set_logger() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_test_writer()
        .init();
}

async fn init_context() -> anyhow::Result<()> {
    set_logger();
    crate::init("target/test_data".to_string()).await?;
    Ok(())
}

#[tokio::test]
async fn test_init() -> anyhow::Result<()> {
    init_context().await?;
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_cookie_store() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT
        .client
        .get("https://baidu.com/")
        .header("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36")
        .send()
        .await?;
    let text = response.text().await?;
    println!("{}", text);
    Ok(())
}

#[test]
fn test_parse_user_detail() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/ud.txt")?;
    let ud = Wenku8Client::parse_user_detail(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&ud)?);
    Ok(())
}

#[test]
fn test_parse_novel_info() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/ti.txt")?;
    let info = Wenku8Client::parse_novel_info(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&info)?);
    let text = std::fs::read_to_string("target/ti2.txt")?;
    let info = Wenku8Client::parse_novel_info(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&info)?);
    Ok(())
}

#[test]
fn test_parse_index() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/idx.txt")?;
    let index = Wenku8Client::parse_index(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&index)?);
    Ok(())
}

#[test]
fn test_parse_reader() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/rd.txt")?;
    let reader = Wenku8Client::parse_reader(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&reader)?);
    Ok(())
}

#[test]
fn test_parse_tags() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/tags.txt")?;
    let tags = Wenku8Client::parse_tags(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_tag_page() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/tag_page.txt")?;
    let tags = Wenku8Client::parse_tag_page(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_toplist() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/toplist.txt")?;
    let tags = Wenku8Client::parse_toplist(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_articlelist() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/articlelist.txt")?;
    let tags = Wenku8Client::parse_articlelist(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_bookcase_list() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/bookcase_list.txt")?;
    let tags = Wenku8Client::parse_bookcase_list(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_book_in_case() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/book_in_case.txt")?;
    let tags = Wenku8Client::parse_book_in_case(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn test_parse_reviews() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/rv.txt")?;
    let tags = Wenku8Client::parse_reviews(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[test]
fn parse_search() -> anyhow::Result<()> {
    let text = std::fs::read_to_string("target/search.txt")?;
    let tags = Wenku8Client::parse_search(text.as_str())?;
    println!("{}", serde_json::to_string_pretty(&tags)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_novel_info() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.novel_info("3").await?;
    println!("response : {}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_add_bookshelf() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.add_bookshelf("1143").await?;
    println!("response : {}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_c_content() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.c_content("3103", "128331").await?;
    println!("response : {}", response);
    Ok(())
}

/// 把章节页的 #content 抽成正文（含插图标记），方便用真实取样页面做离线断言
fn extract_fixture(html: &str) -> String {
    let document = scraper::Html::parse_document(html);
    let selector = scraper::Selector::parse("#content").unwrap();
    let content = document.select(&selector).next().expect("#content");
    let mut buf = String::new();
    Wenku8Client::extract_content_text(content, &mut buf, "https://www.wenku8.net");
    buf.trim().to_string()
}

#[test]
fn test_extract_chapter_illustration_markers() {
    // 插图章节（取样自 /novel/1/1269/40162.htm）：只剩插图标记，水印 <ul> 要剔除
    let text = extract_fixture(include_str!("../test_data/chapter_illustration.html"));
    assert!(!text.contains("轻小说文库"), "水印没剔掉: {text}");
    let urls: Vec<&str> = text
        .split('\n')
        .filter_map(|line| {
            line.strip_prefix("<!--image-->")
                .and_then(|rest| rest.strip_suffix("<!--image-->"))
        })
        .collect();
    assert_eq!(
        urls,
        vec![
            "https://pic.777743.xyz/1/1269/40162/48046.jpg",
            "https://pic.777743.xyz/1/1269/40162/48047.jpg",
            "https://pic.777743.xyz/1/1269/40162/48048.jpg",
        ],
        "插图标记不对: {text}"
    );
    // 每张图独占一行（Dart 侧按行切分）
    assert!(!text.contains("<!--image--><!--image-->"), "两张图挤在一行: {text}");
}

#[test]
fn test_extract_chapter_text_with_image() {
    // 正文章节（取样自 /novel/1/1269/40156.htm）：文字按 <br> 换行 + 中间插一张图
    let text = extract_fixture(include_str!("../test_data/chapter_text.html"));
    assert!(text.contains("——很久很久以前。"), "正文丢了: {text}");
    assert!(text.contains("战争持续了长久一段时间。"), "正文丢了: {text}");
    assert!(text.contains('\n'), "没有把 <br> 换成换行: {text}");
    // src 是相对占位符、data-src 是绝对地址 → 取绝对地址
    assert!(
        text.contains("<!--image-->https://pic.777743.xyz/1/1269/40156/48099.jpg<!--image-->"),
        "插图标记不对: {text}"
    );
    assert!(!text.contains("<img"), "标签没剔掉: {text}");
}

#[tokio::test(flavor = "multi_thread")]
async fn test_tag_page() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.tag_page("治愈", "1", 1).await?;
    println!("{}", serde_json::to_string_pretty(&response)?);
    Ok(())
}

#[tokio::test(flavor = "multi_thread")]
async fn test_reviews() -> anyhow::Result<()> {
    init_context().await?;
    let response = CLIENT.reviews("2441", 1).await?;
    println!("response : {}", serde_json::to_string_pretty(&response)?);
    Ok(())
}
