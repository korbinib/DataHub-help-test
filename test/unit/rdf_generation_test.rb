require 'test_helper'
require 'libxml'

class RDFGenerationTest < ActiveSupport::TestCase

  include RightField

  test "rightfield rdf generation" do
    df=Factory :rightfield_annotated_datafile
    assert_not_nil(df.content_blob)
    rdf = generate_rightfield_rdf(df)
    assert_not_nil(rdf)


    #just checks it is valid rdf/xml and contains some statements for now
    RDF::Reader.for(:rdfxml).new(rdf) do |reader|
      assert_equal 2,reader.statements.count
      assert_equal RDF::URI.new("http://localhost:3000/data_files/#{df.id}"), reader.statements.first.subject
    end
  end



  test "rdf generation job created after save" do
    item = nil

    assert_difference("Delayed::Job.count",1) do
      item = Factory :project
    end
    assert_difference("Delayed::Job.count",1) do
      item.title="sdfhsdfkhsdfklsdf2"
      item.save!
    end
    item = Factory :model
    item.last_used_at=Time.now
    assert_no_difference("Delayed::Job.count") do
      item.save!
    end
  end

  test "rdf storage path" do
    public = Factory(:assay, :policy=>Factory(:public_policy))
    assert_equal File.join(Rails.root,"tmp/testing-filestore/tmp/rdf/public","Assay-#{public.id}.rdf"), public.rdf_storage_path

    private = Factory(:assay, :policy=>Factory(:private_policy))
    assert_equal File.join(Rails.root,"tmp/testing-filestore/tmp/rdf/private","Assay-#{private.id}.rdf"), private.rdf_storage_path
  end

  test "save rdf" do
    assay = Factory(:assay, :policy=>Factory(:public_policy))
    assert assay.can_view?(nil)

    expected_rdf_file = File.join(Rails.root,"tmp/testing-filestore/tmp/rdf/public","Assay-#{assay.id}.rdf")
    FileUtils.rm expected_rdf_file if File.exists?(expected_rdf_file)

    assay.save_rdf

    assert File.exists?(expected_rdf_file)
    rdf=""
    open(expected_rdf_file) do |f|
      rdf = f.read
    end
    assert_equal assay.to_rdf,rdf
    FileUtils.rm expected_rdf_file
    assert !File.exists?(expected_rdf_file)
  end

  test "save private rdf" do
    sop = Factory(:sop, :policy=>Factory(:private_policy))
    assert !sop.can_view?(nil)

    expected_rdf_file = File.join(Rails.root,"tmp/testing-filestore/tmp/rdf/private","Sop-#{sop.id}.rdf")
    FileUtils.rm expected_rdf_file if File.exists?(expected_rdf_file)

    sop.save_rdf

    assert File.exists?(expected_rdf_file)
    rdf=""
    open(expected_rdf_file) do |f|
      rdf = f.read
    end
    assert_equal sop.to_rdf,rdf
    FileUtils.rm expected_rdf_file
    assert !File.exists?(expected_rdf_file)
  end

  test "rdf moves from public to private when permissions change" do
    User.with_current_user Factory(:user) do
      assay = Factory(:assay, :policy=>Factory(:public_policy))
      assert assay.can_view?(nil)

      public_rdf_file = File.join(Rails.root,"tmp/testing-filestore/tmp/rdf/public","Assay-#{assay.id}.rdf")
      private_rdf_file = File.join(Rails.root,"tmp/testing-filestore/tmp/rdf/private","Assay-#{assay.id}.rdf")
      FileUtils.rm public_rdf_file if File.exists?(public_rdf_file)
      FileUtils.rm private_rdf_file if File.exists?(private_rdf_file)

      file = assay.save_rdf
      assert_equal public_rdf_file, file

      assert File.exists?(public_rdf_file)
      assert !File.exists?(private_rdf_file)

      assay.policy=Factory(:private_policy)
      disable_authorization_checks do
        assay.save!
      end

      assert !assay.can_view?(nil)
      file = assay.save_rdf
      assert_equal private_rdf_file, file

      assert File.exists?(private_rdf_file)
      assert !File.exists?(public_rdf_file)

      assay.policy=Factory(:public_policy)
      disable_authorization_checks do
        assay.save!
      end

      assert assay.can_view?(nil)
      file = assay.save_rdf
      assert_equal public_rdf_file, file

      assert File.exists?(public_rdf_file)
      assert !File.exists?(private_rdf_file)
    end

  end

  test "rightfield rdf graph generation" do
    df=Factory :rightfield_annotated_datafile
    rdf = generate_rightfield_rdf_graph(df)
    assert_not_nil rdf
    assert rdf.is_a?(RDF::Graph)
    assert_equal 2,rdf.statements.count
    assert_equal RDF::URI.new("http://localhost:3000/data_files/#{df.id}"), rdf.statements.first.subject

  end

  test "datafile to_rdf" do
    df=Factory :rightfield_annotated_datafile
    rdf = df.to_rdf
    assert_not_nil rdf
    #just checks it is valid rdf/xml and contains some statements for now
    RDF::Reader.for(:rdfxml).new(rdf) do |reader|
      assert reader.statements.count > 0
      assert_equal RDF::URI.new("http://localhost:3000/data_files/#{df.id}"), reader.statements.first.subject
    end
  end

  test "non spreadsheet datafile to_rdf" do
    df=Factory :non_spreadsheet_datafile
    rdf = df.to_rdf
    assert_not_nil rdf

    RDF::Reader.for(:rdfxml).new(rdf) do |reader|
      assert reader.statements.count > 0
      assert_equal RDF::URI.new("http://localhost:3000/data_files/#{df.id}"), reader.statements.first.subject
    end
  end

  test "xlsx datafile to_rdf" do
    df=Factory :xlsx_spreadsheet_datafile

    rdf = df.to_rdf
    assert_not_nil rdf

    RDF::Reader.for(:rdfxml).new(rdf) do |reader|
      assert reader.statements.count > 0
      assert_equal RDF::URI.new("http://localhost:3000/data_files/#{df.id}"), reader.statements.first.subject
    end
  end

end