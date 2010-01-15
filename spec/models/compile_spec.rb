require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Compile do
  describe "validate_compile" do
    before(:each) do
      @user = User.create!
      @compile = Compile.new(:token => @user.token)
    end

    it "should create a project with a random name if none is supplied" do
      @compile.validate_compile
      @compile.project.name.should_not be_blank
    end

    it "should find an existing project if the name is already in use by the user" do
      @project = Project.create!(:name => 'Existing Project', :user => @user)
      @compile.name = @project.name
      @compile.validate_compile
      @compile.project.should eql(@project)
    end

    it "should create a new project if the name is already in use but by a different user" do
      @another_user = User.create!
      @project = Project.create!(:name => 'Existing Project', :user => @another_user)
      @compile.validate_compile
      @compile.project.should_not eql(@project)
    end

    it "should raise a CLSI::InvalidToken error if it's token doesn't correspond to a user" do
      @compile.token = Digest::MD5.hexdigest('blah')
      lambda{
        @compile.validate_compile
      }.should raise_error(CLSI::InvalidToken, 'user does not exist')
    end
    
    it "should raise a CLSI::UnknownCompiler error if it has an unknown compiler" do
      @compile.compiler = 'gcc'
      lambda{
        @compile.validate_compile
      }.should raise_error(CLSI::UnknownCompiler, 'gcc is not a valid compiler')
    end

    it "should raise a CLSI::ImpossibleOutputFormat error" do
      @compile.compiler = 'pdflatex'
      @compile.output_format = 'avi'
      lambda{
        @compile.validate_compile
      }.should raise_error(CLSI::ImpossibleOutputFormat, 'pdflatex cannot produce avi output')
    end
  end

  describe "successful compile" do
    before(:all) do
      @compile = Compile.new
      @user = User.create!
      @project = Project.create!(:name => 'Test Project', :user => @user)
      @compile.user = @user
      @compile.project = @project
      @compile.root_resource_path = 'main.tex'
      @compile.resources = []
      @compile.resources << Resource.new(
        'main.tex', nil,
        '\\documentclass{article} \\begin{document} \\input{chapters/chapter1} \\end{document}', nil,
        @project,
        @user
      )
      @compile.resources << Resource.new(
        'chapters/chapter1.tex', nil,
        'Chapter1 Content!', nil,
        @project,
        @user
      )
    end
    
    shared_examples_for 'an output format of pdf' do
      it "should return the PDF for access by the client" do
        rel_pdf_path = File.join('output', @project.unique_id, 'output.pdf')
        @compile.return_files.should include(rel_pdf_path)
        File.exist?(File.join(SERVER_ROOT_DIR, rel_pdf_path)).should be_true
      end
    end
    
    shared_examples_for 'an output format of dvi' do
      it "should return the DVI for access by the client" do
        rel_path = File.join('output', @project.unique_id, 'output.dvi')
        @compile.return_files.should include(rel_path)
        File.exist?(File.join(SERVER_ROOT_DIR, rel_path)).should be_true
      end
    end

    shared_examples_for 'an output format of ps' do
      it "should return the PostScript file for access by the client" do
        rel_path = File.join('output', @project.unique_id, 'output.ps')
        @compile.return_files.should include(rel_path)
        File.exist?(File.join(SERVER_ROOT_DIR, rel_path)).should be_true
      end
    end
    
    shared_examples_for 'a successful compile' do
      it "should return the log for access by the client" do
        rel_log_path = File.join('output', @project.unique_id, 'output.log')
        @compile.return_files.should include(rel_log_path)
        File.exist?(File.join(SERVER_ROOT_DIR, rel_log_path)).should be_true
      end
    end
    
    it 'should validate the compile' do
      @compile.should_receive(:validate_compile)
      @compile.compile
    end
    
    describe 'with pdflatex compiler and output format of pdf' do
      before do
        @compile.compile
      end
      
      it_should_behave_like 'an output format of pdf'
      it_should_behave_like 'a successful compile'
    end

    describe 'with latex compiler and output format of dvi' do
      before do
        @compile.compiler = 'latex'
        @compile.output_format = 'dvi'
        @compile.compile
      end

      it_should_behave_like 'an output format of dvi'
      it_should_behave_like 'a successful compile'
    end
    
    describe 'with latex compiled and output format of pdf' do
      before do
        @compile.compiler = 'latex'
        @compile.output_format = 'pdf'
        @compile.compile
      end

      it_should_behave_like 'an output format of pdf'
      it_should_behave_like 'a successful compile'
    end

    describe 'with latex compiled and output format of ps' do
      before do
        @compile.compiler = 'latex'
        @compile.output_format = 'ps'
        @compile.compile
      end

      it_should_behave_like 'an output format of ps'
      it_should_behave_like 'a successful compile'
    end

    after(:all) do
      FileUtils.rm_r(File.join(LATEX_COMPILE_DIR, @project.unique_id))
      FileUtils.rm_r(File.join(SERVER_ROOT_DIR, 'output', @project.unique_id))
    end
  end

  describe "unsuccessful compile" do
    before(:all) do
      @compile = Compile.new
      @user = User.create!
      @project = Project.create!(:name => 'Test Project', :user => @user)
      @compile.user = @user
      @compile.project = @project
      @compile.root_resource_path = 'main.tex'
      @compile.resources = []
      @compile.resources << Resource.new(
        'main.tex', nil,
        '\\begin{document}', nil,
        @project,
        @user
      )
      lambda {@compile.compile}.should raise_error CLSI::NoOutputProduced
    end

    it "should return the log for access by the client" do
      rel_log_path = File.join('output', @project.unique_id, 'output.log')
      @compile.return_files.should include(rel_log_path)
      File.exist?(File.join(SERVER_ROOT_DIR, rel_log_path)).should be_true
    end

    after(:all) do
      FileUtils.rm_r(File.join(LATEX_COMPILE_DIR, @project.unique_id))
      FileUtils.rm_r(File.join(SERVER_ROOT_DIR, 'output', @project.unique_id))
    end
  end

  describe "timedout compile" do
    it "should timeout" do
      @compile = Compile.new
      lambda {
        @compile.send('run_with_timeout', "sh " + File.expand_path(RAILS_ROOT + '/spec/fixtures/sleep.sh'), 0.1) 
      }.should raise_error CLSI::Timeout
      %x[ps -a -x].should_not include('/bin/sleep') # lets hope no one else has sleep running!
    end
  end
end
