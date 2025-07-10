# scraper.py
import requests
from bs4 import BeautifulSoup

def scrape_ielts_liz_part1():
    """
    Scrapes IELTS Speaking Part 1 questions from a specific page on ieltsliz.com.
    """
    URL = "https://ieltsliz.com/ielts-speaking-part-1-topics/"
    try:
        page = requests.get(URL, timeout=10)
        page.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)
    except requests.RequestException as e:
        print(f"Error fetching URL: {e}")
        return []

    soup = BeautifulSoup(page.content, "html.parser")
    
    # Find the main content area of the blog post
    content_div = soup.find("div", class_="entry-content")
    
    if not content_div:
        return []

    questions = []
    # The questions are in <strong> tags followed by text
    topics = content_div.find_all("strong")
    
    for topic in topics:
        # The questions are the text that comes immediately after the <strong> tag
        # We can get this using .next_sibling
        if topic.next_sibling and isinstance(topic.next_sibling, str):
            # Split the string of questions into a list of individual questions
            raw_questions = topic.next_sibling.strip().split("?")
            for q in raw_questions:
                # Clean up and add the question mark back
                if q.strip():
                    questions.append(q.strip() + "?")

    # The first few "topics" are not real topics, so we skip them.
    # This might need adjustment if the site changes.
    return questions[5:] if len(questions) > 5 else questions

if __name__ == '__main__':
    # This allows you to run "python scraper.py" to test it
    all_questions = scrape_ielts_liz_part1()
    print(f"Successfully scraped {len(all_questions)} questions.")
    for i, question in enumerate(all_questions[:10]): # Print first 10
        print(f"{i+1}. {question}")