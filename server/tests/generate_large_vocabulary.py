#!/usr/bin/env python3
"""
Generate large vocabulary CSV files for performance testing.

Usage:
    python generate_large_vocabulary.py --count 1000 --output /tmp/test_vocab.csv
    python generate_large_vocabulary.py --count 5000 --type technical --output large.csv
"""

import argparse
import csv
import random
from pathlib import Path


# Word banks for different vocabulary types
TECHNICAL_TERMS = [
    # Programming languages
    "Python", "JavaScript", "TypeScript", "Java", "C++", "Rust", "Go", "Swift", "Kotlin", "Ruby",
    # Frameworks
    "React", "Vue", "Angular", "Django", "Flask", "Express", "SpringBoot", "FastAPI", "NextJS",
    # Infrastructure
    "Kubernetes", "Docker", "AWS", "Azure", "GCP", "Terraform", "Ansible", "Jenkins", "GitLab",
    # Databases
    "PostgreSQL", "MongoDB", "Redis", "Elasticsearch", "Cassandra", "MySQL", "SQLite", "DynamoDB",
    # Protocols/APIs
    "GraphQL", "gRPC", "REST", "WebSocket", "MQTT", "HTTP", "HTTPS", "OAuth", "JWT",
    # Tools
    "GitHub", "GitLab", "Bitbucket", "Jira", "Confluence", "Slack", "VSCode", "IntelliJ",
]

MEDICAL_TERMS = [
    # Medications
    "acetaminophen", "ibuprofen", "amoxicillin", "metformin", "lisinopril", "atorvastatin",
    # Conditions
    "hypertension", "diabetes", "thrombocytopenia", "pneumonia", "bronchitis", "arthritis",
    # Procedures
    "electrocardiogram", "echocardiogram", "colonoscopy", "endoscopy", "angiography",
    # Anatomy
    "cardiovascular", "gastrointestinal", "respiratory", "neurological", "musculoskeletal",
]

BUSINESS_TERMS = [
    # Finance
    "amortization", "depreciation", "capitalization", "ROI", "EBITDA", "P&L", "balance sheet",
    # Marketing
    "SEO", "SEM", "CPC", "CTR", "conversion rate", "customer acquisition cost", "lifetime value",
    # Operations
    "supply chain", "logistics", "inventory management", "quality assurance", "Six Sigma",
]

CHINESE_NAMES = [
    ("李明", "lǐ míng", "Li Ming"),
    ("王芳", "wáng fāng", "Wang Fang"),
    ("张伟", "zhāng wěi", "Zhang Wei"),
    ("刘洋", "liú yáng", "Liu Yang"),
    ("陈静", "chén jìng", "Chen Jing"),
    ("杨帆", "yáng fān", "Yang Fan"),
    ("赵敏", "zhào mǐn", "Zhao Min"),
    ("孙强", "sūn qiáng", "Sun Qiang"),
    ("周磊", "zhōu lěi", "Zhou Lei"),
    ("吴娜", "wú nà", "Wu Na"),
    ("北京", "běi jīng", "Beijing"),
    ("上海", "shàng hǎi", "Shanghai"),
    ("深圳", "shēn zhèn", "Shenzhen"),
    ("广州", "guǎng zhōu", "Guangzhou"),
]

CATEGORIES = ["technical", "medical", "business", "mixed"]


def generate_vocabulary_entries(count: int, vocab_type: str = "mixed") -> list:
    """
    Generate vocabulary entries for CSV export.

    Args:
        count: Number of entries to generate
        vocab_type: Type of vocabulary (technical, medical, business, mixed)

    Returns:
        List of dictionaries with term, pronunciation, mapping, category
    """
    entries = []

    # Determine word bank based on type
    if vocab_type == "technical":
        word_bank = TECHNICAL_TERMS
        categories = ["programming", "framework", "infrastructure", "database", "tool"]
    elif vocab_type == "medical":
        word_bank = MEDICAL_TERMS
        categories = ["medication", "condition", "procedure", "anatomy"]
    elif vocab_type == "business":
        word_bank = BUSINESS_TERMS
        categories = ["finance", "marketing", "operations"]
    else:  # mixed
        word_bank = TECHNICAL_TERMS + MEDICAL_TERMS + BUSINESS_TERMS
        categories = ["technical", "medical", "business", "other"]

    # Add base terms
    for i in range(min(count, len(word_bank))):
        term = word_bank[i]
        entries.append({
            "term": term,
            "pronunciation": "",  # Empty for English terms
            "mapping": "",
            "category": random.choice(categories)
        })

    # If we need more entries, generate variations
    remaining = count - len(entries)
    if remaining > 0:
        for i in range(remaining):
            base_term = random.choice(word_bank)
            # Add numeric suffix to create unique variations
            term = f"{base_term}{i % 1000}"
            entries.append({
                "term": term,
                "pronunciation": "",
                "mapping": "",
                "category": random.choice(categories)
            })

    # Add some Chinese entries (10% of total or max 100)
    chinese_count = min(int(count * 0.1), 100, len(CHINESE_NAMES))
    for i in range(chinese_count):
        chinese, pinyin, mapping = CHINESE_NAMES[i % len(CHINESE_NAMES)]
        # Add variation suffix if needed
        suffix = f"{i}" if i >= len(CHINESE_NAMES) else ""
        entries.append({
            "term": f"{chinese}{suffix}",
            "pronunciation": pinyin,
            "mapping": f"{mapping}{suffix}" if suffix else mapping,
            "category": "name"
        })

    return entries[:count]  # Ensure exact count


def write_csv(entries: list, output_path: str):
    """
    Write vocabulary entries to CSV file with UTF-8 encoding.

    Args:
        entries: List of entry dictionaries
        output_path: Output file path
    """
    output_file = Path(output_path)
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        fieldnames = ['term', 'pronunciation', 'mapping', 'category']
        writer = csv.DictWriter(f, fieldnames=fieldnames)

        writer.writeheader()
        writer.writerows(entries)

    print(f"✅ Generated {len(entries)} entries → {output_path}")
    print(f"   File size: {output_file.stat().st_size / 1024:.1f} KB")


def main():
    parser = argparse.ArgumentParser(
        description="Generate large vocabulary CSV files for performance testing"
    )
    parser.add_argument(
        '--count',
        type=int,
        default=1000,
        help='Number of vocabulary entries to generate (default: 1000)'
    )
    parser.add_argument(
        '--type',
        choices=CATEGORIES,
        default='mixed',
        help='Type of vocabulary to generate (default: mixed)'
    )
    parser.add_argument(
        '--output',
        type=str,
        default='/tmp/test_vocabulary.csv',
        help='Output CSV file path (default: /tmp/test_vocabulary.csv)'
    )
    parser.add_argument(
        '--verify',
        action='store_true',
        help='Verify UTF-8 encoding after generation'
    )

    args = parser.parse_args()

    print(f"Generating {args.count} {args.type} vocabulary entries...")
    entries = generate_vocabulary_entries(args.count, args.type)

    write_csv(entries, args.output)

    if args.verify:
        # Verify UTF-8 encoding
        import subprocess
        try:
            result = subprocess.run(
                ['file', args.output],
                capture_output=True,
                text=True
            )
            if 'UTF-8' in result.stdout:
                print("✅ UTF-8 encoding verified")
            else:
                print(f"⚠️  Warning: {result.stdout.strip()}")
        except Exception as e:
            print(f"⚠️  Could not verify encoding: {e}")

    # Print sample entries
    print("\nSample entries:")
    for entry in entries[:5]:
        print(f"  - {entry['term']} ({entry.get('category', 'N/A')})")
    if len(entries) > 5:
        print(f"  ... and {len(entries) - 5} more")


if __name__ == '__main__':
    main()
