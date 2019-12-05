require_relative "../spec_helper"

Struct.new("Responder", :body)
Struct.new("Fetcher", :_get) {
  def get(url, hsh)
    ; return _get;
  end }

require 'pry'

require 'dotenv'
Dotenv.load('.env')

def fetcher(text)
  fetcher = Struct::Fetcher.new(Struct::Responder.new(text))

  f = Rubyfocus::OSSFetcher.new("foo", "bar")
  f.fetcher = fetcher
  f
end

describe Rubyfocus::OSSFetcher do
  describe 'mocked' do
    let(:html) { webpage(
      "20151016190000=basefile_id+basefile.zip",
      "20151016190100=basefile+patch1.zip",
      "20151016190200=patch1+patch2.zip",
      "20151016190300=patch2+patch3.zip"
    ) }

    let(:encrypted_html) { webpage(
      "20151016190000=basefile_id+basefile.zip",
      "20151016190100=basefile+patch1.zip",
      "20151016190200=patch1+patch2.zip",
      "20151016190300=patch2+patch3.zip",
      "encrypted"
    ) }

    let(:base_fetcher) { fetcher(html) }

    let(:encrypted_fetcher) { fetcher(encrypted_html) }

    describe "#patches" do
      it "should return a list of files, as HTML" do
        r = double(body: html)

        fetcher = double("Fetcher")
        expect(fetcher).to receive(:get).with("https://sync2.omnigroup.com/foo/OmniFocus.ofocus", digest_auth: {username: "foo", password: "bar"}).and_return(r)

        f = Rubyfocus::OSSFetcher.new("foo", "bar")
        f.fetcher = fetcher

        patches = f.patches
        expect(patches.first.file).to eq("20151016190000=basefile_id+basefile.zip")
        expect(patches.last.file).to eq("20151016190300=patch2+patch3.zip")
      end
    end

    describe "#base_id" do
      it "should return the id of the base" do
        expect(base_fetcher.base_id).to eq("basefile")
      end
    end

    describe "#patch" do
      it "should retrieve and unzip a zipped file" do
        # First, collect some zipped data
        zip_file = Dir[File.join(file("basic.ofocus"), "*.zip")].first
        zipped_data = File.read(zip_file)

        r = double(body: zipped_data)
        fetcher = double(get: r)

        f = Rubyfocus::OSSFetcher.new("foo", "bar")
        f.fetcher = fetcher
        expect(f.patch("random")).to include(%|<?xml version="1.0" encoding="UTF-8" standalone="no"?>|)
      end
    end

    describe "#encrypted?" do
      it "should recognise encrypted databases by the presence of an `encrypted` file" do
        expect(base_fetcher).to_not be_encrypted
        expect(encrypted_fetcher).to be_encrypted
      end
    end
  end

  describe 'live' do
    let(:omnifocus_username) { ENV['OMNIFOCUS_WEB_USERNAME'] }
    let(:omnifocus_password) { ENV['OMNIFOCUS_WEB_PASSWORD'] }

    let(:live_instance) {
      described_class.new(omnifocus_username, omnifocus_password)
    }

    before do
      expect(omnifocus_username).not_to be_nil
      expect(omnifocus_password).not_to be_nil
    end

    describe '#files' do
      it 'fetches the files' do
        files = live_instance.files
        expect(files).to be_an_instance_of(Array)
        expect(files.select { |filename| filename.include? omnifocus_username }.count).to eq 1
      end
    end

    describe '#patches' do
      it 'Fetches a list of every patch file' do
        expect(live_instance.patches).to be_an_instance_of(Array)
        expect(live_instance.patches.size).to eq 1942
      end
    end

    describe "#base_id" do
      it "should return the id of the base" do
        base_file_id = "pyvX1T7gjRg"
        expect(live_instance.base_id).to eq(base_file_id)
      end
    end

    describe "#base" do
      it "should return the base" do
        expect(live_instance.base).to be_an_instance_of(String)
      end
    end
  end
end
